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
    argparser.add_argument("-e", "--error-action")
    argparser.add_argument("heartbeats", nargs="+")
    args = argparser.parse_args()

    print(f"watching heartbeats {repr(args.heartbeats)}. timout: {args.timeout_min}, action: {repr(args.action)}, error-action: {repr(args.error_action)}", flush=True)
    
    heartbeats = touch_heartbeats(args.heartbeats)
    try:
        watch_heartbeats(heartbeats, args.timeout_min)
        os.system(args.action)
    except Exception as e:
        sys.stderr.write(f"Exception: {e}\n")
        os.system(args.error_action)
    return


def touch_heartbeats(heartbeats: List[str]) -> List[Path]:
    paths = [Path(h) for h in heartbeats]
    for path in paths:
        path.touch()
    return paths


def watch_heartbeats(heartbeats: List[Path], timeout_min: int) -> Path:
    while True:
        if all([time.time() - heartbeat.lstat().st_mtime >= timeout_min * 60 for heartbeat in heartbeats]):
            return
        time.sleep(60)


if __name__ == "__main__":
    main()
