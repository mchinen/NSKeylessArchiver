# NSKeylessArchiver-iOS
Cocotron-based NSArchiver to provide faster encoding than NSKeyed*chiver when keys are not needed

## When to use
If you have a moderate to large use case for NSKeyedArchiver that does not rely on keys (e.g. uses only -[NSCoder encodeObject:] and -[NSCoder encodeObjectOfObjcType: at:] as opposed to -[NSCoder encodeObject: forKey:]), then you may be able to use this.  The keyed based encoding and decoding is much slower, because it allows for random access.  The non-keyed method allows a faster linear, forward-only read and write because it requires the order of encoding and decoding to be fixed.  Mac OS X has a deprecated NSArchiver/NSUnarchiver, and iOS has this, but is not a public API.

## How do I get backward-compatibility without keys?
A frequent cited advantage of NSKeyedArchiver is that the keys provide easy backward-compatibility.   It certainly helps, but of course, backward compatibility can exist without keys.
If you store a version number, you can still add and remove new objects/data, and check the version number on load to determine whether or not to decode or not.  If this is not clear I will expand on it later.


## Performance
First of, if fast-as-possible performance is your goal, you might consider something else, such as directly writing to a binary file.  This is a trade off for having the convenience of having a drop-in replacement for compliant uses of NSKeyedArchiver.

For a test case, I compared NSKeyedArchiver, NSKeylessArchiver, and NSArchiver with a simple root object with 20000 ints.  Please feel free modify the [test repo](https://github.com/mchinen/NSArchiverPerformance) and this class to improve performance and correctness.  This was the typical result:

`NSKeylessArchiver encoding time 0.025590 decoding time 0.009438`
`NSArchiver encoding time 0.003826 decoding time 0.000927`
`NSKeyedArchiver encoding time 2.722656 decoding time 2.659569`

As you can see the performance for this unrealistic use case shows NSKeylessArchiver doing much better than NSKeyedArchiver, but worse than NSArchiver.  NSArchiver is a better choice, but apps that use it may not pass iOS app review due to the private API status.  If you know otherwise, let me know.

In practical use, I have seen about a 2-5x speed increase for a use case that had ~20,000 ints/floats/objects being encoded/decoded.
It seems logical that the gains will be larger for encoding schemes that have a larger ratio of encoding calls to actual data being encoded.

