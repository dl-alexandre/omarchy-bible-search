#!/usr/bin/env python3
"""Install the optional WEBP corpus through an fd-relative transaction.

The shell command deliberately delegates this path-sensitive operation here.
Every directory used by the transaction is opened with O_NOFOLLOW and checked
through its descriptor.  Files are created exclusively, downloads are streamed
through a pipe into an already-open descriptor, and renames/cleanup use stable
parent descriptors rather than re-resolving absolute paths.
"""

from __future__ import annotations

import argparse
import errno
import hashlib
import os
import re
import secrets
import shutil
import stat
import subprocess
import sys
import zipfile
from typing import NoReturn


ARCHIVE_MEMBER = "engwebp_vpl.txt"
STAGE_PREFIX = "stage."
MAX_LINE_BYTES = 1024 * 1024
BOOK_HEADER = re.compile(r"^([A-Z0-9]{3})\s+[0-9]+:[0-9]+\s+")

BOOK_NAMES = {
    "GEN": "Genesis",
    "EXO": "Exodus",
    "LEV": "Leviticus",
    "NUM": "Numbers",
    "DEU": "Deuteronomy",
    "JOS": "Joshua",
    "JDG": "Judges",
    "RUT": "Ruth",
    "1SA": "1-Samuel",
    "2SA": "2-Samuel",
    "1KI": "1-Kings",
    "2KI": "2-Kings",
    "1CH": "1-Chronicles",
    "2CH": "2-Chronicles",
    "EZR": "Ezra",
    "NEH": "Nehemiah",
    "EST": "Esther",
    "JOB": "Job",
    "PSA": "Psalms",
    "PRO": "Proverbs",
    "ECC": "Ecclesiastes",
    "SOL": "Song-of-Solomon",
    "ISA": "Isaiah",
    "JER": "Jeremiah",
    "LAM": "Lamentations",
    "EZE": "Ezekiel",
    "DAN": "Daniel",
    "HOS": "Hosea",
    "JOE": "Joel",
    "AMO": "Amos",
    "OBA": "Obadiah",
    "JON": "Jonah",
    "MIC": "Micah",
    "NAH": "Nahum",
    "HAB": "Habakkuk",
    "ZEP": "Zephaniah",
    "HAG": "Haggai",
    "ZEC": "Zechariah",
    "MAL": "Malachi",
    "MAT": "Matthew",
    "MAR": "Mark",
    "LUK": "Luke",
    "JOH": "John",
    "ACT": "Acts",
    "ROM": "Romans",
    "1CO": "1-Corinthians",
    "2CO": "2-Corinthians",
    "GAL": "Galatians",
    "EPH": "Ephesians",
    "PHI": "Philippians",
    "COL": "Colossians",
    "1TH": "1-Thessalonians",
    "2TH": "2-Thessalonians",
    "1TI": "1-Timothy",
    "2TI": "2-Timothy",
    "TIT": "Titus",
    "PHM": "Philemon",
    "HEB": "Hebrews",
    "JAM": "James",
    "1PE": "1-Peter",
    "2PE": "2-Peter",
    "1JO": "1-John",
    "2JO": "2-John",
    "3JO": "3-John",
    "JUD": "Jude",
    "REV": "Revelation",
}


class SetupError(RuntimeError):
    """A user-actionable setup failure without a traceback."""


def fail(message: str) -> NoReturn:
    raise SetupError(message)


def close_fd(descriptor: int | None) -> None:
    if descriptor is None:
        return
    try:
        os.close(descriptor)
    except OSError:
        pass


def required_open_flags() -> int:
    required = ("O_NOFOLLOW", "O_DIRECTORY", "O_CLOEXEC")
    missing = [name for name in required if not hasattr(os, name)]
    if missing:
        fail(f"secure setup requires open flags unavailable on this system: {', '.join(missing)}")
    return os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC


def check_directory(
    descriptor: int,
    label: str,
    *,
    require_owner: bool,
    tighten: bool,
) -> None:
    try:
        info = os.fstat(descriptor)
    except OSError as exc:
        fail(f"could not inspect {label}: {exc.strerror or exc}")
    if not stat.S_ISDIR(info.st_mode):
        fail(f"{label} is not a directory")

    effective_uid = os.geteuid()
    if require_owner and info.st_uid != effective_uid:
        fail(f"{label} is not owned by the current user")
    if info.st_uid not in (0, effective_uid):
        fail(f"{label} has an unexpected owner")

    mode = stat.S_IMODE(info.st_mode)
    if info.st_uid == 0:
        writable_by_others = mode & 0o022
        sticky = bool(mode & stat.S_ISVTX)
        if writable_by_others and not sticky:
            fail(f"refusing writable root-owned directory: {label}")
    elif mode & 0o022 and not tighten:
        fail(f"refusing group/world-writable directory: {label}")

    if tighten:
        try:
            os.fchmod(descriptor, 0o700)
            info = os.fstat(descriptor)
        except OSError as exc:
            fail(f"could not restrict {label}: {exc.strerror or exc}")
        if info.st_uid != effective_uid or stat.S_IMODE(info.st_mode) & 0o077:
            fail(f"could not verify restricted ownership for {label}")


def open_directory_chain(path: str, label: str) -> int:
    normalized = os.path.abspath(os.path.normpath(os.path.expanduser(path)))
    if "\x00" in normalized or normalized == "/":
        fail(f"invalid {label} path")

    flags = required_open_flags()
    descriptor: int | None = None
    try:
        descriptor = os.open("/", flags)
        components = [component for component in normalized.split(os.sep) if component]
        for index, component in enumerate(components):
            try:
                child = os.open(component, flags, dir_fd=descriptor)
            except FileNotFoundError:
                try:
                    os.mkdir(component, 0o700, dir_fd=descriptor)
                except FileExistsError:
                    pass
                try:
                    child = os.open(component, flags, dir_fd=descriptor)
                except OSError as exc:
                    if exc.errno in (errno.ELOOP, errno.ENOTDIR):
                        try:
                            if stat.S_ISLNK(os.lstat(component, dir_fd=descriptor).st_mode):
                                fail(f"refusing symlink in {label} path: {component}")
                        except FileNotFoundError:
                            pass
                    fail(f"could not open {label} component {component}: {exc.strerror or exc}")
            except OSError as exc:
                if exc.errno in (errno.ELOOP, errno.ENOTDIR):
                    try:
                        if stat.S_ISLNK(os.lstat(component, dir_fd=descriptor).st_mode):
                            fail(f"refusing symlink in {label} path: {component}")
                    except FileNotFoundError:
                        pass
                fail(f"could not open {label} component {component}: {exc.strerror or exc}")

            check_directory(
                child,
                f"{label} component {component}",
                require_owner=index == len(components) - 1,
                tighten=index == len(components) - 1,
            )
            close_fd(descriptor)
            descriptor = child

        if descriptor is None:
            fail(f"invalid {label} path")
        return descriptor
    except SetupError:
        close_fd(descriptor)
        raise
    except OSError as exc:
        close_fd(descriptor)
        fail(f"could not open {label}: {exc.strerror or exc}")


def open_child_directory(parent: int, name: str, label: str) -> int:
    flags = required_open_flags()
    try:
        try:
            descriptor = os.open(name, flags, dir_fd=parent)
        except FileNotFoundError:
            os.mkdir(name, 0o700, dir_fd=parent)
            descriptor = os.open(name, flags, dir_fd=parent)
        check_directory(descriptor, label, require_owner=True, tighten=True)
        return descriptor
    except FileExistsError:
        return open_child_directory(parent, name, label)
    except OSError as exc:
        if exc.errno in (errno.ELOOP, errno.ENOTDIR):
            try:
                if stat.S_ISLNK(os.lstat(name, dir_fd=parent).st_mode):
                    fail(f"refusing symlink directory: {label}")
            except FileNotFoundError:
                pass
        fail(f"could not open {label}: {exc.strerror or exc}")


def assert_regular_file(descriptor: int, label: str) -> None:
    try:
        info = os.fstat(descriptor)
    except OSError as exc:
        fail(f"could not inspect {label}: {exc.strerror or exc}")
    if not stat.S_ISREG(info.st_mode):
        fail(f"{label} is not a regular file")
    if info.st_uid != os.geteuid():
        fail(f"{label} is not owned by the current user")


def new_file(parent: int) -> tuple[str, int]:
    flags = os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC
    for _ in range(32):
        name = f"{STAGE_PREFIX}{secrets.token_hex(16)}"
        try:
            descriptor = os.open(name, flags, 0o600, dir_fd=parent)
        except FileExistsError:
            continue
        except OSError as exc:
            fail(f"could not create exclusive staging file: {exc.strerror or exc}")
        try:
            assert_regular_file(descriptor, "staging file")
        except SetupError:
            close_fd(descriptor)
            try:
                os.unlink(name, dir_fd=parent)
            except OSError:
                pass
            raise
        return name, descriptor
    fail("could not create a unique staging file")


def new_directory(parent: int) -> tuple[str, int]:
    flags = required_open_flags()
    for _ in range(32):
        name = f"{STAGE_PREFIX}{secrets.token_hex(16)}"
        try:
            os.mkdir(name, 0o700, dir_fd=parent)
            descriptor = os.open(name, flags, dir_fd=parent)
        except FileExistsError:
            continue
        except OSError as exc:
            fail(f"could not create exclusive staging directory: {exc.strerror or exc}")
        try:
            check_directory(descriptor, "staging directory", require_owner=True, tighten=True)
        except SetupError:
            close_fd(descriptor)
            try:
                os.rmdir(name, dir_fd=parent)
            except OSError:
                pass
            raise
        return name, descriptor
    fail("could not create a unique staging directory")


def write_all(descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    while view:
        try:
            written = os.write(descriptor, view)
        except OSError as exc:
            fail(f"could not write staging data: {exc.strerror or exc}")
        if written <= 0:
            fail("could not write staging data")
        view = view[written:]


def sync_fd(descriptor: int, label: str) -> None:
    try:
        os.fsync(descriptor)
    except OSError as exc:
        fail(f"could not sync {label}: {exc.strerror or exc}")


def download_to_file(descriptor: int, url: str, max_bytes: int) -> None:
    curl = shutil.which("curl")
    if curl is None:
        fail("curl is required for secure WEBP setup")

    command = [
        curl,
        "--fail",
        "--location",
        "--retry",
        "3",
        "--connect-timeout",
        "10",
        "--max-time",
        "180",
        "--max-filesize",
        str(max_bytes),
        "--output",
        "-",
        url,
    ]
    process: subprocess.Popen[bytes] | None = None
    try:
        process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            close_fds=True,
        )
        assert process.stdout is not None
        total = 0
        while True:
            chunk = process.stdout.read(min(64 * 1024, max_bytes - total + 1))
            if not chunk:
                break
            total += len(chunk)
            if total > max_bytes:
                process.kill()
                process.wait()
                fail(f"downloaded WEBP archive exceeds the {max_bytes}-byte size limit")
            write_all(descriptor, chunk)
        return_code = process.wait()
        if return_code != 0:
            fail(f"curl failed while downloading the WEBP archive (exit {return_code})")
        sync_fd(descriptor, "downloaded WEBP archive")
    except SetupError:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        raise
    except OSError as exc:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        fail(f"could not download the WEBP archive: {exc.strerror or exc}")
    finally:
        if process is not None and process.stdout is not None:
            process.stdout.close()


def sha256_file(descriptor: int) -> tuple[str, int]:
    digest = hashlib.sha256()
    total = 0
    try:
        os.lseek(descriptor, 0, os.SEEK_SET)
        while True:
            chunk = os.read(descriptor, 64 * 1024)
            if not chunk:
                break
            digest.update(chunk)
            total += len(chunk)
        os.lseek(descriptor, 0, os.SEEK_SET)
    except OSError as exc:
        fail(f"could not hash the downloaded WEBP archive: {exc.strerror or exc}")
    return digest.hexdigest(), total


class CorpusWriter:
    def __init__(self, staging_directory: int) -> None:
        self.staging_directory = staging_directory
        self.current_file: int | None = None
        self.current_verse = ""
        self.book_files: dict[str, int] = {}

    def _book_file(self, code: str) -> int | None:
        book = BOOK_NAMES.get(code)
        if book is None:
            return None
        if book in self.book_files:
            return self.book_files[book]
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC
        try:
            descriptor = os.open(f"{book}.txt", flags, 0o600, dir_fd=self.staging_directory)
        except OSError as exc:
            fail(f"could not create staged book file {book}.txt: {exc.strerror or exc}")
        assert_regular_file(descriptor, f"staged book file {book}.txt")
        self.book_files[book] = descriptor
        return descriptor

    def _flush(self) -> None:
        if self.current_file is not None and self.current_verse:
            write_all(self.current_file, (self.current_verse + "\n").encode("utf-8"))
        self.current_verse = ""

    def feed(self, raw_line: bytes) -> None:
        line = raw_line.decode("utf-8", errors="replace").rstrip("\r").strip()
        if not line:
            return
        if "\x00" in line:
            fail("downloaded WEBP corpus contained a NUL byte")
        match = BOOK_HEADER.match(line)
        if match:
            self._flush()
            self.current_file = self._book_file(match.group(1))
            self.current_verse = line
        elif self.current_verse:
            self.current_verse += " " + line

    def finish(self) -> int:
        self._flush()
        count = len(self.book_files)
        for descriptor in self.book_files.values():
            sync_fd(descriptor, "staged book file")
            close_fd(descriptor)
        self.book_files.clear()
        return count


def extract_and_split(
    archive_descriptor: int,
    corpus_descriptor: int,
    staging_directory: int,
    max_corpus_bytes: int,
) -> int:
    try:
        duplicate = os.dup(archive_descriptor)
        stream = os.fdopen(duplicate, "rb", closefd=True)
        archive = zipfile.ZipFile(stream)
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as exc:
        fail(f"downloaded WEBP archive failed ZIP integrity validation: {exc}")

    try:
        infos = archive.infolist()
        if len(infos) != 1 or infos[0].filename != ARCHIVE_MEMBER or infos[0].is_dir():
            fail("downloaded WEBP archive did not contain exactly one engwebp_vpl.txt member")
        info = infos[0]
        if info.file_size <= 0:
            fail("downloaded WEBP archive contained an empty corpus")
        if info.file_size > max_corpus_bytes:
            fail(f"downloaded WEBP corpus exceeds the {max_corpus_bytes}-byte size limit")
        if archive.testzip() is not None:
            fail("downloaded WEBP archive failed ZIP integrity validation")

        writer = CorpusWriter(staging_directory)
        pending = bytearray()
        total = 0
        with archive.open(info, "r") as member:
            while True:
                chunk = member.read(64 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_corpus_bytes:
                    fail(f"downloaded WEBP corpus exceeds the {max_corpus_bytes}-byte size limit")
                write_all(corpus_descriptor, chunk)
                pending.extend(chunk)
                while True:
                    newline = pending.find(b"\n")
                    if newline < 0:
                        break
                    writer.feed(bytes(pending[:newline]))
                    del pending[: newline + 1]
                if len(pending) > MAX_LINE_BYTES:
                    fail("downloaded WEBP corpus contained an overlong line")
        if pending:
            writer.feed(bytes(pending))
        book_count = len(writer.book_files)
        writer.finish()
        if total == 0:
            fail("downloaded WEBP archive contained an empty corpus")
        if book_count == 0:
            fail("the downloaded corpus did not contain readable book files")
        sync_fd(corpus_descriptor, "staged WEBP corpus")
        return book_count
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as exc:
        fail(f"downloaded WEBP archive failed validation: {exc}")
    finally:
        archive.close()


def existing_entry(parent: int, name: str, label: str) -> os.stat_result | None:
    try:
        info = os.stat(name, dir_fd=parent, follow_symlinks=False)
    except FileNotFoundError:
        return None
    except OSError as exc:
        fail(f"could not inspect {label}: {exc.strerror or exc}")
    if stat.S_ISLNK(info.st_mode):
        fail(f"refusing to replace symlink {label}")
    if info.st_uid != os.geteuid():
        fail(f"{label} is not owned by the current user")
    return info


def open_existing_directory(parent: int, name: str, label: str) -> int | None:
    info = existing_entry(parent, name, label)
    if info is None:
        return None
    if not stat.S_ISDIR(info.st_mode):
        fail(f"{label} is not a directory")
    flags = required_open_flags()
    try:
        descriptor = os.open(name, flags, dir_fd=parent)
    except OSError as exc:
        fail(f"could not open {label}: {exc.strerror or exc}")
    try:
        check_directory(descriptor, label, require_owner=True, tighten=False)
    except SetupError:
        close_fd(descriptor)
        raise
    return descriptor


def replace_file(parent: int, stage_name: str, final_name: str, label: str, expected: int) -> None:
    existing_entry(parent, final_name, label)
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC
    try:
        source = os.open(stage_name, flags, dir_fd=parent)
        source_info = os.fstat(source)
        expected_info = os.fstat(expected)
    except OSError as exc:
        fail(f"could not revalidate staged {label}: {exc.strerror or exc}")
    try:
        if (source_info.st_dev, source_info.st_ino) != (expected_info.st_dev, expected_info.st_ino):
            fail(f"staged {label} changed before installation")
    finally:
        close_fd(source)
    try:
        os.replace(stage_name, final_name, src_dir_fd=parent, dst_dir_fd=parent)
    except OSError as exc:
        fail(f"could not install {label}: {exc.strerror or exc}")
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC
    try:
        descriptor = os.open(final_name, flags, dir_fd=parent)
    except OSError as exc:
        fail(f"could not revalidate {label}: {exc.strerror or exc}")
    try:
        assert_regular_file(descriptor, label)
    finally:
        close_fd(descriptor)


def remove_tree(parent: int, name: str) -> None:
    flags = required_open_flags()
    try:
        descriptor = os.open(name, flags, dir_fd=parent)
    except FileNotFoundError:
        return
    except OSError as exc:
        if exc.errno not in (errno.ENOTDIR, errno.ELOOP):
            raise
        try:
            os.unlink(name, dir_fd=parent)
        except FileNotFoundError:
            pass
        return
    try:
        for child in os.listdir(descriptor):
            info = os.lstat(child, dir_fd=descriptor)
            if stat.S_ISDIR(info.st_mode) and not stat.S_ISLNK(info.st_mode):
                remove_tree(descriptor, child)
            else:
                try:
                    os.unlink(child, dir_fd=descriptor)
                except FileNotFoundError:
                    pass
    finally:
        close_fd(descriptor)
    try:
        os.rmdir(name, dir_fd=parent)
    except FileNotFoundError:
        pass


def unlink_file(parent: int | None, name: str | None) -> None:
    if parent is None or name is None:
        return
    try:
        os.unlink(name, dir_fd=parent)
    except FileNotFoundError:
        pass


def revalidate_directory(parent: int, name: str, label: str, expected: int) -> None:
    flags = required_open_flags()
    try:
        descriptor = os.open(name, flags, dir_fd=parent)
    except OSError as exc:
        fail(f"could not revalidate {label}: {exc.strerror or exc}")
    try:
        actual = os.fstat(descriptor)
        original = os.fstat(expected)
        if (actual.st_dev, actual.st_ino) != (original.st_dev, original.st_ino):
            fail(f"{label} changed before installation")
        check_directory(descriptor, label, require_owner=True, tighten=True)
    finally:
        close_fd(descriptor)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--max-download-bytes", required=True, type=int)
    parser.add_argument("--max-corpus-bytes", required=True, type=int)
    return parser.parse_args()


def setup(args: argparse.Namespace) -> None:
    if not re.fullmatch(r"[0-9a-fA-F]{64}", args.sha256):
        fail("WEBP checksum must be a 64-character SHA-256 value")
    if args.max_download_bytes <= 0 or args.max_corpus_bytes <= 0:
        fail("WEBP size limits must be positive")

    data_directory: int | None = None
    cache_directory: int | None = None
    archive_descriptor: int | None = None
    corpus_descriptor: int | None = None
    staging_directory: int | None = None
    backup_directory: int | None = None
    old_books_directory: int | None = None
    archive_stage: str | None = None
    corpus_stage: str | None = None
    staging_name: str | None = None
    backup_name: str | None = None
    books_moved = False
    success = False

    try:
        data_directory = open_directory_chain(args.data_root, "data root")
        cache_directory = open_child_directory(data_directory, "cache", "cache directory")

        existing_entry(cache_directory, "engwebp_vpl.zip", "WEBP archive")
        existing_entry(cache_directory, "engwebp_vpl.txt", "WEBP corpus cache")
        old_books_directory = open_existing_directory(data_directory, "books", "book directory")

        archive_stage, archive_descriptor = new_file(cache_directory)
        print("Downloading the public-domain World English Bible (WEBP)…")
        download_to_file(archive_descriptor, args.url, args.max_download_bytes)
        checksum, archive_size = sha256_file(archive_descriptor)
        if archive_size > args.max_download_bytes:
            fail(f"downloaded WEBP archive exceeds the {args.max_download_bytes}-byte size limit")
        if checksum.lower() != args.sha256.lower():
            fail("downloaded WEBP archive failed SHA-256 verification")

        corpus_stage, corpus_descriptor = new_file(cache_directory)
        staging_name, staging_directory = new_directory(data_directory)
        extract_and_split(
            archive_descriptor,
            corpus_descriptor,
            staging_directory,
            args.max_corpus_bytes,
        )
        sync_fd(staging_directory, "staged book directory")

        # The parent descriptors remain stable for the entire commit.  The
        # source directory is revalidated against its original descriptor
        # immediately before the fd-relative rename.
        revalidate_directory(data_directory, staging_name, "staged book directory", staging_directory)
        if old_books_directory is not None:
            revalidate_directory(data_directory, "books", "book directory", old_books_directory)
            backup_name, backup_directory = new_directory(data_directory)
            os.rename(
                "books",
                "prev",
                src_dir_fd=data_directory,
                dst_dir_fd=backup_directory,
            )
            books_moved = True
            sync_fd(backup_directory, "book backup directory")
        os.rename(
            staging_name,
            "books",
            src_dir_fd=data_directory,
            dst_dir_fd=data_directory,
        )
        staging_name = None
        revalidate_directory(data_directory, "books", "installed book directory", staging_directory)
        close_fd(staging_directory)
        staging_directory = None
        close_fd(old_books_directory)
        old_books_directory = None
        sync_fd(data_directory, "data root")

        replace_file(
            cache_directory,
            archive_stage,
            "engwebp_vpl.zip",
            "WEBP archive",
            archive_descriptor,
        )
        archive_stage = None
        replace_file(
            cache_directory,
            corpus_stage,
            "engwebp_vpl.txt",
            "WEBP corpus cache",
            corpus_descriptor,
        )
        corpus_stage = None
        sync_fd(cache_directory, "cache directory")

        success = True
        print(f"Installed WEBP at {os.path.join(os.path.abspath(args.data_root), 'books')}")
        print(f"Source: {args.url}")
    except SetupError:
        raise
    except (OSError, ValueError) as exc:
        fail(f"secure WEBP setup failed: {exc.strerror if isinstance(exc, OSError) and exc.strerror else exc}")
    finally:
        close_fd(archive_descriptor)
        close_fd(corpus_descriptor)
        close_fd(staging_directory)
        close_fd(old_books_directory)

        if not success and books_moved and backup_directory is not None and data_directory is not None:
            try:
                if not existing_entry(data_directory, "books", "book directory"):
                    os.rename(
                        "prev",
                        "books",
                        src_dir_fd=backup_directory,
                        dst_dir_fd=data_directory,
                    )
            except (OSError, SetupError):
                pass

        if archive_stage is not None:
            unlink_file(cache_directory, archive_stage)
        if corpus_stage is not None:
            unlink_file(cache_directory, corpus_stage)
        if staging_name is not None and data_directory is not None:
            remove_tree(data_directory, staging_name)
        if backup_name is not None and not success and data_directory is not None:
            remove_tree(data_directory, backup_name)

        close_fd(backup_directory)
        close_fd(cache_directory)
        close_fd(data_directory)


def main() -> int:
    try:
        setup(parse_args())
    except SetupError as exc:
        print(f"omarchy-bible-search: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
