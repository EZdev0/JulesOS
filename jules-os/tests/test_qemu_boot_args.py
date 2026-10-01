#!/usr/bin/env python3
import unittest
import os
import re

class TestQEMUBootArgs(unittest.TestCase):
    def test_rootfs_arg_present(self):
        # We need to make sure root=/dev/ram0 rw is passed in the non-universal boot path
        test_file = os.path.join(os.path.dirname(__file__), 'qemu_boot_test.py')

        with open(test_file, 'r') as f:
            content = f.read()

        # Very simple heuristic: looking for the -append definition
        self.assertIn("root=/dev/ram0 rw", content,
                      "The QEMU boot test MUST include root=/dev/ram0 rw to mount the rootfs")

if __name__ == '__main__':
    unittest.main()
