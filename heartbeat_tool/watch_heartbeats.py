#!/usr/bin/python3

import argparse
import sys
from typing import List
from pathlib import Path
import os
import time

def main():
    argparser = argparse.ArgumentParser("watch_heartbeats")
    argparser.add_argument("-t", "--timeout-min", type=int)
    argparser.add_argument("-a", "--action")
    argparser.add_argument("heartbeats", nargs="+")
    args = argparser.parse_args()
    
    heartbeats = touch_heartbeats(args.heartbeats)
    watch_heartbeats(heartbeats, args.timeout_min)
    os.system(args.action)
    return


def touch_heartbeats(heartbeats: List[str]) -> List[Path]:
    paths = [Path(h) for h in heartbeats]
    for path in paths:
        path.touch()
    return paths


def watch_heartbeats(heartbeats: List[Path], timeout_min: int) -> Path:
    while True:
        time.sleep(60)
        for heartbeat in heartbeats:
            if time.time() - heartbeat.lstat().st_mtime >= timeout_min * 60:
                return heartbeat


if __name__ == "__main__":
    main()