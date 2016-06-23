
How to create a release
-----------------------

First update info.plist and set new version number, then

```bash
git commit -am "Version X.X.X"
git tag -a vX.X.X -m "Version X.X.X"
git push origin master --tags
```
