# NSKeylessArchiver-iOS
Cocotron-based NSArchiver to provide faster encoding than NSKeyed*chiver when keys are not needed.  Modified by Michael Chinen becase Cocotron version was old and did not compile for iOS.

## How to use
Add NSKeylessArchiver and NSKeylessUnarchiver's .h and .m files to your project.  If you have an arc project, you will need to go into the "Build Phases" tab of your project settings and add the '-fno-objc-arc' flag to both NSKeylessArchiver.m and NSKeylessUnarchiver.m.

Then, just #import "NSKeylessArchiver.h" and use it like an NSCoder.  See the performance test project below for a sample.

## When to use
If you have a moderate to large use case for NSKeyedArchiver that does not rely on keys (e.g. uses only -[NSCoder encodeObject:] and -[NSCoder encodeObjectOfObjcType: at:] as opposed to -[NSCoder encodeObject: forKey:]), then you may be able to use this.  The keyed based encoding and decoding is much slower, because it allows for random access.  The non-keyed method allows a faster linear, forward-only read and write because it requires the order of encoding and decoding to be fixed.  Mac OS X has a deprecated NSArchiver/NSUnarchiver, and iOS has this, but is not a public API.

## How do I get backward-compatibility without keys?  Forward-compatibility?
A frequent cited advantage of NSKeyedArchiver is that the keys provide easy backward-compatibility.   It certainly helps, but of course, backward compatibility can exist without keys.
If you store a version number, you can still add and remove new objects/data, and check the version number on load to determine whether or not to decode or not.  If this is not clear I will expand on it later.
Forward-compatibility via keys is much harder, but in the 'save user data' case, you may not need it - the only way that you will need to load a file from a future version is for cloud-based methods.
If you do need it, it is possible to implement schema for forward-compatibility with NSKeylessArchiver, by using keys implicitly in an NSDictionary (which you should be able to use with NSKeylessArchiver!).  The other options are probably too messy, and likely remnicent of file formats that specify a byte length of each component and subcomponent, in which case you should just write your own binary file.


## Performance
First of, if fast-as-possible performance is your goal, you might consider something else, such as directly writing to a binary file.  This is a trade off for having the convenience of having a drop-in replacement for compliant uses of NSKeyedArchiver.

For a test case, I compared NSKeyedArchiver, NSKeylessArchiver, and NSArchiver with a simple root object with 20000 ints.  Please feel free modify the [test repo](https://github.com/mchinen/NSArchiverPerformance) and this class to improve performance and correctness.  This was the result of running a release build on an iPhone 5S, with 10 runs per class:


|                 |encoding (min/max/avg secs)|decoding (min/max/avg secs)|
|-----------------|:-------------------------:|:-------------------------:|
|NSKeyedArchiver  |  0.2048/0.2453/0.2165     |  6.8919/6.9238/6.9037|
|NSKeylessArchiver|  0.0407/0.0506/0.0451     |  0.0253/0.0330/0.0287|
|NSArchiver       |  0.0094/0.0114/0.0102     |  0.0019/0.0025/0.0020|



As you can see the performance for this unrealistic use case shows NSKeylessArchiver doing much better than NSKeyedArchiver, but worse than NSArchiver.  NSArchiver is a better choice, but apps that use it may not pass iOS app review due to the private API status.  If you know otherwise, let me know.

In practical use, I have seen about a 2-5x speed increase for a use case that had ~20,000 ints/floats/objects being encoded/decoded.
It seems logical that the gains will be larger for encoding schemes that have a larger ratio of encoding calls to actual data being encoded.

