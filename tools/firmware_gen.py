# -*- coding: utf-8 -*-
import os
import getopt
import sys
# hash需要调用的库
import hashlib

if __name__ == "__main__":
    inputfile = ''
    outputfile = ''
    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hi:o:asn', ['ifile=', 'ofile='])
    except getopt.GetoptError:
        print('rsa+noaes.py -i <inputfile> -o <outputfile>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print('rsa+noaes.py -i <inputfile> -o <outputfile>')
            sys.exit()
        elif opt in ('-i', '--ifile'):
            inputfile = arg
        elif opt in ('-o', '--ofile'):
            outputfile = arg
    # 在firmware中添加版本号version
    with open(inputfile, 'rb+') as f:
        origin_content = f.read()
        f.seek(0, 0)
        # write version
        version = b'\x00\x00\x00\x00'
        f.write(version + origin_content)
        f.close()

    input = open(inputfile, 'rb')
    patch_otp = open(outputfile, 'wb')
    input_data = input.read()
    """
    # file length
    file_len = len(input_data)
    data_len = file_len
    """
    # construct file header
    # write Magic
    magic = b'\x4b\x32\x33\x30'
    print('the magic is: ', magic)
    patch_otp.write(magic)
    """
    # write length
    length = struct.pack('I', data_len)
    print('the length of firmware: ', data_len)
    patch_otp.write(length)
    """
    # 全局变量
    message = input_data
    # 判断生成哪种形式的固件头
    # 写长度: （version+固件明文）
    data_len = len(input_data)
    data_len_byte = data_len.to_bytes(4, byteorder=sys.byteorder, signed=True)  # int convert 4 bytes
    patch_otp.write(data_len_byte)
    # write encryption type
    encrypto_type = 0
    encrypto_type_b = encrypto_type.to_bytes(4, byteorder=sys.byteorder, signed=True)  # int convert bytes
    patch_otp.write(encrypto_type_b)
    # 对明文做hash256
    hash_data = hashlib.sha256(message).digest()
    # 写hash头
    patch_otp.write(hash_data)
    # 保留（516-32）字节
    reverse_value = bytes(516-32)
    patch_otp.write(reverse_value)

    # write firmware
    patch_otp.write(message)
    patch_otp.close()
    input.close()
