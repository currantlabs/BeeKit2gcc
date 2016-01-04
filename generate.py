#!/usr/bin/env python
# encoding: utf-8

# Usage:
#   first argument is the .cproject file
#   second argument is the output file

import xml.etree.ElementTree as etree
import re
import sys

root = etree.parse(sys.argv[1]).getroot()

release_conf = root.find(".//configuration[@name='RELEASE']")

pre_build = release_conf.attrib["prebuildStep"]
post_build = release_conf.attrib["postbuildStep"]

include_dirs = list()
defines = list()
cflags = list()
cppflags = list()
ldflags = list()
ldlibs = list()

compiler, linker = (None, None)

# Extract subtrees for compiler and linker options
for tool in release_conf.iter('tool'):
    i = tool.attrib["id"]
    if "c.compiler" in i:
        compiler = tool
    elif "c.linker" in i:
        linker = tool

for compiler_opt in compiler.iter("option"):
    opt_id = compiler_opt.attrib["id"]
    if "include.paths" in opt_id:
        for path in compiler_opt.iter():
            value = path.get("value")
            if value and "ARM_GCC_Support" not in value:
                # Normalize and append include paths
                include_dirs.append(value.strip('"').replace('\\', '/'))
    elif compiler_opt.get('valueType') == "boolean" and \
            compiler_opt.get('value') == 'true':
        # Extract and append compiler flags to CFLAGS
        flag = re.search('\((.*)\)', compiler_opt.get("name"))
        value = flag.group(1).strip()
        if value == "-nostdinc":
            # This flag breaks compilation, we need string.h from default include
            continue
        cflags.append(value)
    elif "preprocessor.def" in opt_id:
        # Extract and append preprocessor defines
        for define in compiler_opt.iter():
            value = define.get("value")
            if value:
                defines.append(value)
    elif "other.otherflags" in opt_id:
        # Add remaining compiler flags
        cflags.extend(compiler_opt.attrib["value"].split())

for linker_opt in linker.iter("option"):
    opt_id = linker_opt.attrib["id"]
    if "option.ldflags" in opt_id:
        for flag in linker_opt.iter():
            value = flag.get("value")
            # Don't add start-group and end-group options, we add that
            # in our Makefile
            if not value or value in ("--start-group", "--end-group"):
                continue

            # Append libraries to LDLIBS
            if value.startswith("-l"):
                ldlibs.append(value)
            else:
                ldflags.append("-Wl,"+value)
    elif "option.otherflags" in opt_id:
        ldflags.extend(linker_opt.attrib["value"].split())
    # Extract linker flags
    elif linker_opt.get('valueType') == "boolean" and \
            linker_opt.get('value') == 'true':
        flag = re.search('\((.*)\)', linker_opt.get("name"))
        ldflags.append(flag.group(1))
    # Extract Library Paths
    if "link.option.paths" in opt_id:
        for path in linker_opt.iter():
            value = path.get("value")
            if value and "ARM_GCC_Support" not in value:
                ldflags.append("-L" + value.strip('"').replace('\\', '/'))
    # Extract LDLIBS
    if "link.option.libs" in opt_id:
        for lib in linker_opt.iter():
            value = lib.get("value")
            if value:
                ldlibs.append("-l" + value)

with open(sys.argv[2], 'w') as conf_file:
    conf_file.write('CFLAGS=' + " \\\n".join(cflags) + '\n')
    conf_file.write('CPPFLAGS=' + " \\\n".join([" -I"
                    + i for i in include_dirs])
                    + " \\\n".join([" -D" + d for d in defines]) + '\n')
    conf_file.write('LDFLAGS=' + " ".join(ldflags) + '\n')
    conf_file.write('LDLIBS=' + " ".join(ldlibs) + '\n')
