#!/bin/bash

set -xe

odin build src -out=bin/remap_debug -o:none -debug
gdb bin/remap_debug
