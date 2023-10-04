#!/bin/bash

set -e

if [ -f demo_nodes.env ]; then
    source demo_nodes.env
fi

# installed version
# source /root/demo_nodes.env

/root/demo_ws/install/demo_nodes_cpp/lib/demo_nodes_cpp/$1
