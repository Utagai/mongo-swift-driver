<!--
  Make sure you have read CONTRIBUTING.md completely before you file a new
  issue! 

  If possible, try to determine if the bug is actually part of the Swift driver,
  or if the issue is actually from `libmongoc` or `libbson`. If so, you should
  file the issue with the representative projects.
-->

## Information

**Swift version**

What does this command give you?
```
$ swift --version
```

Operating System:

What does this command give you?
```
$ uname -a
```

Driver version:

What does this command give you?
```
$ cat Package.swift
```

Version of `libmongoc` and `libbson`:
```
$ brew list --versions mongo-c-driver # Only applies if you installed via brew
```

How did you install `libmongoc` and `libbson` on your system:
Did you use `brew`? Did you install them manually? etc.

## What is the problem? 

*BE SPECIFIC*:
1. What is the _expected_ behavior and what is _actually_ happening?
2. Do you have any particular output that demonstrates this problem?
3. Do you have any ideas on _why_ this may be happening that could give us a
clue in the right direction?
4. Did this issue arise out of nowhere, after an update (of the driver? of
Swift?)? 
5. Is there a workaround that seems to avoid this this issue?
6. Are there multiple ways of triggering this bug (perhaps more than one
function produce a crash)?

## Reproducing the bug

1. First, do this.
2. Then do this.
3. After doing that, do this.
4. And then, finally, do this.
5. Bug occurs.