"""Create five packed XGA commissioning patterns and a playback plan (stdlib only)."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    names = ["black", "white", "vertical", "horizontal", "checker"]
    for kind, name in enumerate(names):
        data = bytearray()
        for y in range(768):
            for xbyte in range(128):
                white = (False, True, (xbyte//4)%2 == 1,
                         (y//32)%2 == 1, ((xbyte//4)+(y//32))%2 == 1)[kind]
                data.append(255 if white else 0)
        path = args.output / (name + ".bin")
        if path.exists():
            raise FileExistsError(path)
        path.write_bytes(data)
    plan = {"patterns": [n + ".bin" for n in names], "sequence": [0, 1, 2, 3, 4],
            "repeat_count": 2, "period_us": [20]}
    with (args.output / "plan.json").open("x") as stream:
        json.dump(plan, stream, indent=2)
    print(args.output / "plan.json")


if __name__ == "__main__":
    main()
