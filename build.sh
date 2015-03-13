
set -e


## Initialize variables

CODE_SIGN_IDENTITY_PARAM="A=B" #default can't be ""
if [ "$CODE_SIGN_IDENTITY" != "" ]; then
  CODE_SIGN_IDENTITY_PARAM='CODE_SIGN_IDENTITY="'$CODE_SIGN_IDENTITY'"'
fi


## Clean

rm -rf Build

mkdir -p Build/appstax-ios


## Build framework

cd Appstax
xcodebuild test -scheme Appstax -sdk iphonesimulator "$CODE_SIGN_IDENTITY_PARAM"
xcodebuild build -configuration Release -scheme AppstaxUniversal SYMROOT="../Build/xcodebuild" "$CODE_SIGN_IDENTITY_PARAM"
cd -

cp -a Build/xcodebuild/Release-universal/Appstax.framework Build/appstax-ios/Appstax.framework


## Copy to Build/appstax-ios

cp -a StarterProjects Build/appstax-ios/StarterProjects
cp -a Examples        Build/appstax-ios/Examples
rm -rf Build/appstax-ios/Examples/Notes/Appstax.framework
rm -rf Build/appstax-ios/StarterProjects/Basic/Appstax.framework
cp -a Build/appstax-ios/Appstax.framework Build/appstax-ios/Examples/Notes/Appstax.framework
cp -a Build/appstax-ios/Appstax.framework Build/appstax-ios/StarterProjects/Basic/Appstax.framework


## ZIP

cd Build
zip -rq appstax-ios.zip appstax-ios
cd -

