# jool-clat

This program configures [jool](https://nicmx.github.io/Jool/en/index.html) as a CLAT. It is heavily based on [clatd](https://github.com/toreanderson/clatd), which does the same with [TAYGA](http://www.litech.org/tayga/)


## Usage
This script is meant to be run whenever your network configuration changes.

## Todo

- [ ] Cleanup:
  - [ ] Remove proxied NDP entries when the prefix changes/ on deconfiguration
  - [ ] Remove old address configured on the clat-side of the veth pair when the prefix changes
  - [ ] Disable IP forwarding on deconfiguration
- [ ] Adjust documentation
- [ ] ???
