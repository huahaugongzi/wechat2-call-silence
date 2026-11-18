import pathlib, struct, shutil, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = pathlib.Path('/Applications/微信 2.app')
EXECUTABLE = APP / 'Contents/MacOS/WeChat'
FRAMEWORKS = APP / 'Contents/Frameworks'
LIBRARY = FRAMEWORKS / 'libwechat2_call_silence.dylib'
BACKUP = ROOT / 'installed-backup'
LOAD_NAME = b'@executable_path/../Frameworks/libwechat2_call_silence.dylib\0'


def patch_executable(original):
    data = bytearray(original)
    if data[:4] != bytes.fromhex('cafebabe'):
        raise ValueError('Expected a universal Mach-O executable')
    count = struct.unpack_from('>I', data, 4)[0]
    command_size = (24 + len(LOAD_NAME) + 7) & ~7
    load_command = struct.pack('<6I', 0xC, command_size, 24, 0, 0, 0) + LOAD_NAME
    load_command += b'\0' * (command_size - len(load_command))

    for index in range(count):
        offset = struct.unpack_from('>I', data, 8 + index * 20 + 8)[0]
        if data[offset:offset + 4] != bytes.fromhex('cffaedfe'):
            raise ValueError(f'Unexpected Mach-O slice at index {index}')
        command_count, command_bytes = struct.unpack_from('<II', data, offset + 16)
        cursor = offset + 32
        for _ in range(command_count):
            _, size = struct.unpack_from('<II', data, cursor)
            if LOAD_NAME[:-1] in data[cursor:cursor + size]:
                raise ValueError('Call suppression library is already linked')
            cursor += size
        if cursor != offset + 32 + command_bytes:
            raise ValueError('Invalid Mach-O load command table')
        if any(data[cursor:cursor + command_size]):
            raise ValueError('No free load-command space; refusing to grow executable')
        data[cursor:cursor + command_size] = load_command
        struct.pack_into('<II', data, offset + 16, command_count + 1, command_bytes + command_size)
    return data


def main():
    if not EXECUTABLE.is_file():
        raise FileNotFoundError(f'WeChat 2 was not found at {APP}')
    original = (BACKUP / 'WeChat').read_bytes()
    patched = patch_executable(original)
    FRAMEWORKS.mkdir(exist_ok=True)
    shutil.copy2(ROOT / 'dist/libwechat2_call_silence.dylib', LIBRARY)
    EXECUTABLE.write_bytes(patched)
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(APP)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], check=True)
    print('Installed only in', APP)


if __name__ == '__main__':
    main()
