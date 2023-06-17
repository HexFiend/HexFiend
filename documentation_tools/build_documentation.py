#!/usr/bin/env python3

from __future__ import print_function

import sys, os, subprocess, distutils.spawn, shutil

env = os.getenv
norm = os.path.normpath

built_products_dir = env("BUILT_PRODUCTS_DIR")
if built_products_dir == None:
    print ("Environmental variable BUILT_PRODUCTS_DIR is missing. This script should be run from within Xcode.")
    sys.exit(1)

src_root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))

config_path= norm(src_root + "/documentation_tools/hexfiend_doxyfile.config")
if not os.path.isfile(config_path):
    print ("Doxygen config file does not exist at " + config_path)
    sys.exit(1)

# Silently take advantage of MacPorts or Homebrew.
doxygen_search = os.pathsep.join((os.environ['PATH'],'/usr/local/bin','/opt/local/bin','/opt/homebrew/bin'))
doxygen_path = os.getenv("DOXYGEN_PATH") or distutils.spawn.find_executable("doxygen", path=doxygen_search)
if not doxygen_path or not os.path.isfile(doxygen_path):
    if os.getenv("DOXYGEN_PATH"):
        print ("Could not find doxygen at DOXYGEN_PATH=", doxygen_path)
    else:
        print ("Could not find doxygen: install doxygen to your PATH, or add a DOXYGEN_PATH")
        sys.exit(1)

# Headers should be a symlink, so get its real path
headers = os.path.realpath(built_products_dir + "/HexFiend.framework/Headers")
if not os.path.isdir(headers):
    print ("The HexFiend header directory does not exist at " + headers)
    sys.exit(1)

output_dir = norm(os.path.join(src_root, 'docs'))
try:
    os.mkdir(output_dir)
except:
    pass
if not os.path.isdir(output_dir):
    print ("The documentation output directory does not exist at " + output_dir)
    sys.exit(1)

print ('Documentation output: ' + output_dir)
sys.stdout.flush()

new_wd = norm(src_root + "/documentation_tools/")

final_output_dir = norm(os.path.join(output_dir, 'docs'))
temp_output_dir = norm(os.path.join(output_dir, 'html'))
shutil.rmtree(final_output_dir)

proc = subprocess.Popen([doxygen_path, '-'], shell=False, cwd=new_wd, stdin=subprocess.PIPE)

conf_file = open(config_path, 'r')
for line in conf_file:
	if line.startswith('INPUT '):
		line = 'INPUT = ' + headers
	elif line.startswith('OUTPUT_DIRECTORY '):
		line = 'OUTPUT_DIRECTORY = ' + output_dir
	# Strip the header path as it probably contains the user name,
	# which we don't want outputted in the html
	elif line.startswith('STRIP_FROM_PATH '):
		line = 'STRIP_FROM_PATH = ' + headers
	proc.stdin.write(line.encode("utf-8"))
proc.stdin.close()
proc.wait()

# Move the 'html' directory to 'docs'
os.rename(temp_output_dir, final_output_dir)

sys.exit(0)
