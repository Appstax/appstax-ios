
Appstax iOS SDK
===============

This is the official SDK for [Appstax](http://appstax.com). Please read the [iOS Guide](http://appstax.com/docs/iOS-SDK-Guide.html) to get up and running.

Installing
----------

[Download the latest release](https://github.com/appstax/appstax-ios/releases/latest) and add Appstax.framework to your app.


Example usage
-------------

```objective-c
[Appstax setAppKey:@"your-app-key"];

AXObject *contact = [AXObject create:@"Contacts"];
contact[@"name"]  = @"John Appleseed";
contact[@"email"] = @"john@appleseed.com";
[contact save];
```

See the [iOS Guide](http://appstax.com/docs/Guides/iOS-SDK-Guide.html) for more info on how to set up your app and data model.


Building from source
--------------------

Open `Appstax/Appstax.xcodeproj` in XCode and build the `AppstaxUniversal` target, or run `./build.sh` on the command line.


License
-------

[MIT License](LICENSE)


