import base64

b64 = "7dTOt9bHB1IxDZgbPe+6QlxlN6bZK6dwsyZXN7rj1/IgARLcbKRqExFTsfAlFZ/PI3dRDdugodytW73pieLB/w=="
raw = base64.b64decode(b64)
print(f"raw bytes: {raw}")

print(f'Length of raw bytes:{len(raw)}')