// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/mac/foundation_util.h"

#include <stdlib.h>
#include <string.h>

#include "base/file_path.h"
#include "base/logging.h"
#include "base/mac/bundle_locations.h"
#include "base/mac/mac_logging.h"
#include "base/sys_string_conversions.h"

extern "C" {
CFTypeID SecACLGetTypeID();
CFTypeID SecTrustedApplicationGetTypeID();
}  // extern "C"

namespace base {
namespace mac {

static bool g_override_am_i_bundled = false;
static bool g_override_am_i_bundled_value = false;

// Adapted from http://developer.apple.com/carbon/tipsandtricks.html#AmIBundled
static bool UncachedAmIBundled() {
  if (g_override_am_i_bundled)
    return g_override_am_i_bundled_value;

  ProcessSerialNumber psn = {0, kCurrentProcess};

  FSRef fsref;
  OSStatus pbErr;
  if ((pbErr = GetProcessBundleLocation(&psn, &fsref)) != noErr) {
    OSSTATUS_DLOG(ERROR, pbErr) << "GetProcessBundleLocation failed";
    return false;
  }

  FSCatalogInfo info;
  OSErr fsErr;
  if ((fsErr = FSGetCatalogInfo(&fsref, kFSCatInfoNodeFlags, &info,
                                NULL, NULL, NULL)) != noErr) {
    OSSTATUS_DLOG(ERROR, fsErr) << "FSGetCatalogInfo failed";
    return false;
  }

  return info.nodeFlags & kFSNodeIsDirectoryMask;
}

bool AmIBundled() {
  // If the return value is not cached, this function will return different
  // values depending on when it's called. This confuses some client code, see
  // http://crbug.com/63183 .
  static bool result = UncachedAmIBundled();
  DCHECK_EQ(result, UncachedAmIBundled())
      << "The return value of AmIBundled() changed. This will confuse tests. "
      << "Call SetAmIBundled() override manually if your test binary "
      << "delay-loads the framework.";
  return result;
}

void SetOverrideAmIBundled(bool value) {
  g_override_am_i_bundled = true;
  g_override_am_i_bundled_value = value;
}

bool IsBackgroundOnlyProcess() {
  // This function really does want to examine NSBundle's idea of the main
  // bundle dictionary.  It needs to look at the actual running .app's
  // Info.plist to access its LSUIElement property.
  NSDictionary* info_dictionary = [base::mac::MainBundle() infoDictionary];
  return [[info_dictionary objectForKey:@"LSUIElement"] boolValue] != NO;
}

FilePath PathForFrameworkBundleResource(CFStringRef resourceName) {
  NSBundle* bundle = base::mac::FrameworkBundle();
  NSString* resourcePath = [bundle pathForResource:(NSString*)resourceName
                                            ofType:nil];
  return NSStringToFilePath(resourcePath);
}

OSType CreatorCodeForCFBundleRef(CFBundleRef bundle) {
  OSType creator = kUnknownType;
  CFBundleGetPackageInfo(bundle, NULL, &creator);
  return creator;
}

OSType CreatorCodeForApplication() {
  CFBundleRef bundle = CFBundleGetMainBundle();
  if (!bundle)
    return kUnknownType;

  return CreatorCodeForCFBundleRef(bundle);
}

bool GetSearchPathDirectory(NSSearchPathDirectory directory,
                            NSSearchPathDomainMask domain_mask,
                            FilePath* result) {
  DCHECK(result);
  NSArray* dirs =
      NSSearchPathForDirectoriesInDomains(directory, domain_mask, YES);
  if ([dirs count] < 1) {
    return false;
  }
  *result = NSStringToFilePath([dirs objectAtIndex:0]);
  return true;
}

bool GetLocalDirectory(NSSearchPathDirectory directory, FilePath* result) {
  return GetSearchPathDirectory(directory, NSLocalDomainMask, result);
}

bool GetUserDirectory(NSSearchPathDirectory directory, FilePath* result) {
  return GetSearchPathDirectory(directory, NSUserDomainMask, result);
}

FilePath GetUserLibraryPath() {
  FilePath user_library_path;
  if (!GetUserDirectory(NSLibraryDirectory, &user_library_path)) {
    DLOG(WARNING) << "Could not get user library path";
  }
  return user_library_path;
}

// Takes a path to an (executable) binary and tries to provide the path to an
// application bundle containing it. It takes the outermost bundle that it can
// find (so for "/Foo/Bar.app/.../Baz.app/..." it produces "/Foo/Bar.app").
//   |exec_name| - path to the binary
//   returns - path to the application bundle, or empty on error
FilePath GetAppBundlePath(const FilePath& exec_name) {
  const char kExt[] = ".app";
  const size_t kExtLength = arraysize(kExt) - 1;

  // Split the path into components.
  std::vector<std::string> components;
  exec_name.GetComponents(&components);

  // It's an error if we don't get any components.
  if (!components.size())
    return FilePath();

  // Don't prepend '/' to the first component.
  std::vector<std::string>::const_iterator it = components.begin();
  std::string bundle_name = *it;
  DCHECK_GT(it->length(), 0U);
  // If the first component ends in ".app", we're already done.
  if (it->length() > kExtLength &&
      !it->compare(it->length() - kExtLength, kExtLength, kExt, kExtLength))
    return FilePath(bundle_name);

  // The first component may be "/" or "//", etc. Only append '/' if it doesn't
  // already end in '/'.
  if (bundle_name[bundle_name.length() - 1] != '/')
    bundle_name += '/';

  // Go through the remaining components.
  for (++it; it != components.end(); ++it) {
    DCHECK_GT(it->length(), 0U);

    bundle_name += *it;

    // If the current component ends in ".app", we're done.
    if (it->length() > kExtLength &&
        !it->compare(it->length() - kExtLength, kExtLength, kExt, kExtLength))
      return FilePath(bundle_name);

    // Separate this component from the next one.
    bundle_name += '/';
  }

  return FilePath();
}

#define TYPE_NAME_FOR_CF_TYPE_DEFN(TypeCF) \
std::string TypeNameForCFType(TypeCF##Ref) { \
  return #TypeCF; \
}

TYPE_NAME_FOR_CF_TYPE_DEFN(CFArray);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFBag);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFBoolean);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFData);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFDate);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFDictionary);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFNull);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFNumber);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFSet);
TYPE_NAME_FOR_CF_TYPE_DEFN(CFString);

#undef TYPE_NAME_FOR_CF_TYPE_DEFN

void NSObjectRetain(void* obj) {
  id<NSObject> nsobj = static_cast<id<NSObject> >(obj);
  [nsobj retain];
}

void NSObjectRelease(void* obj) {
  id<NSObject> nsobj = static_cast<id<NSObject> >(obj);
  [nsobj release];
}

void* CFTypeRefToNSObjectAutorelease(CFTypeRef cf_object) {
  // When GC is on, NSMakeCollectable marks cf_object for GC and autorelease
  // is a no-op.
  //
  // In the traditional GC-less environment, NSMakeCollectable is a no-op,
  // and cf_object is autoreleased, balancing out the caller's ownership claim.
  //
  // NSMakeCollectable returns nil when used on a NULL object.
  return [NSMakeCollectable(cf_object) autorelease];
}

static const char* base_bundle_id;

const char* BaseBundleID() {
  if (base_bundle_id) {
    return base_bundle_id;
  }

#if defined(GOOGLE_CHROME_BUILD)
  return "com.google.Chrome";
#else
  return "org.chromium.Chromium";
#endif
}

void SetBaseBundleID(const char* new_base_bundle_id) {
  if (new_base_bundle_id != base_bundle_id) {
    free((void*)base_bundle_id);
    base_bundle_id = new_base_bundle_id ? strdup(new_base_bundle_id) : NULL;
  }
}

// Definitions for the corresponding CF_TO_NS_CAST_DECL macros in
// foundation_util.h.
#define CF_TO_NS_CAST_DEFN(TypeCF, TypeNS) \
\
TypeNS* CFToNSCast(TypeCF##Ref cf_val) { \
  DCHECK(!cf_val || TypeCF##GetTypeID() == CFGetTypeID(cf_val)); \
  TypeNS* ns_val = \
      const_cast<TypeNS*>(reinterpret_cast<const TypeNS*>(cf_val)); \
  return ns_val; \
} \
\
TypeCF##Ref NSToCFCast(TypeNS* ns_val) { \
  TypeCF##Ref cf_val = reinterpret_cast<TypeCF##Ref>(ns_val); \
  DCHECK(!cf_val || TypeCF##GetTypeID() == CFGetTypeID(cf_val)); \
  return cf_val; \
}

#define CF_TO_NS_MUTABLE_CAST_DEFN(name) \
CF_TO_NS_CAST_DEFN(CF##name, NS##name) \
\
NSMutable##name* CFToNSCast(CFMutable##name##Ref cf_val) { \
  DCHECK(!cf_val || CF##name##GetTypeID() == CFGetTypeID(cf_val)); \
  NSMutable##name* ns_val = reinterpret_cast<NSMutable##name*>(cf_val); \
  return ns_val; \
} \
\
CFMutable##name##Ref NSToCFCast(NSMutable##name* ns_val) { \
  CFMutable##name##Ref cf_val = \
      reinterpret_cast<CFMutable##name##Ref>(ns_val); \
  DCHECK(!cf_val || CF##name##GetTypeID() == CFGetTypeID(cf_val)); \
  return cf_val; \
}

CF_TO_NS_MUTABLE_CAST_DEFN(Array);
CF_TO_NS_MUTABLE_CAST_DEFN(AttributedString);
CF_TO_NS_CAST_DEFN(CFCalendar, NSCalendar);
CF_TO_NS_MUTABLE_CAST_DEFN(CharacterSet);
CF_TO_NS_MUTABLE_CAST_DEFN(Data);
CF_TO_NS_CAST_DEFN(CFDate, NSDate);
CF_TO_NS_MUTABLE_CAST_DEFN(Dictionary);
CF_TO_NS_CAST_DEFN(CFError, NSError);
CF_TO_NS_CAST_DEFN(CFLocale, NSLocale);
CF_TO_NS_CAST_DEFN(CFNumber, NSNumber);
CF_TO_NS_CAST_DEFN(CFRunLoopTimer, NSTimer);
CF_TO_NS_CAST_DEFN(CFTimeZone, NSTimeZone);
CF_TO_NS_MUTABLE_CAST_DEFN(Set);
CF_TO_NS_CAST_DEFN(CFReadStream, NSInputStream);
CF_TO_NS_CAST_DEFN(CFWriteStream, NSOutputStream);
CF_TO_NS_MUTABLE_CAST_DEFN(String);
CF_TO_NS_CAST_DEFN(CFURL, NSURL);

#undef CF_TO_NS_CAST_DEFN
#undef CF_TO_NS_MUTABLE_CAST_DEFN

#define CF_CAST_DEFN(TypeCF) \
template<> TypeCF##Ref \
CFCast<TypeCF##Ref>(const CFTypeRef& cf_val) { \
  if (cf_val == NULL) { \
    return NULL; \
  } \
  if (CFGetTypeID(cf_val) == TypeCF##GetTypeID()) { \
    return (TypeCF##Ref)(cf_val); \
  } \
  return NULL; \
} \
\
template<> TypeCF##Ref \
CFCastStrict<TypeCF##Ref>(const CFTypeRef& cf_val) { \
  TypeCF##Ref rv = CFCast<TypeCF##Ref>(cf_val); \
  DCHECK(cf_val == NULL || rv); \
  return rv; \
}

CF_CAST_DEFN(CFArray);
CF_CAST_DEFN(CFBag);
CF_CAST_DEFN(CFBoolean);
CF_CAST_DEFN(CFData);
CF_CAST_DEFN(CFDate);
CF_CAST_DEFN(CFDictionary);
CF_CAST_DEFN(CFNull);
CF_CAST_DEFN(CFNumber);
CF_CAST_DEFN(CFSet);
CF_CAST_DEFN(CFString);

CF_CAST_DEFN(SecACL);
CF_CAST_DEFN(SecTrustedApplication);

#undef CF_CAST_DEFN

std::string GetValueFromDictionaryErrorMessage(
    CFStringRef key, const std::string& expected_type, CFTypeRef value) {
  ScopedCFTypeRef<CFStringRef> actual_type_ref(
      CFCopyTypeIDDescription(CFGetTypeID(value)));
  return "Expected value for key " +
      base::SysCFStringRefToUTF8(key) +
      " to be " +
      expected_type +
      " but it was " +
      base::SysCFStringRefToUTF8(actual_type_ref) +
      " instead";
}

NSString* FilePathToNSString(const FilePath& path) {
  if (path.empty())
    return nil;
  return [NSString stringWithUTF8String:path.value().c_str()];
}

FilePath NSStringToFilePath(NSString* str) {
  if (![str length])
    return FilePath();
  return FilePath([str fileSystemRepresentation]);
}

}  // namespace mac
}  // namespace base

std::ostream& operator<<(std::ostream& o, const CFStringRef string) {
  return o << base::SysCFStringRefToUTF8(string);
}

std::ostream& operator<<(std::ostream& o, const CFErrorRef err) {
  base::mac::ScopedCFTypeRef<CFStringRef> desc(CFErrorCopyDescription(err));
  base::mac::ScopedCFTypeRef<CFDictionaryRef> user_info(
      CFErrorCopyUserInfo(err));
  CFStringRef errorDesc = NULL;
  if (user_info.get()) {
    errorDesc = reinterpret_cast<CFStringRef>(
        CFDictionaryGetValue(user_info.get(), kCFErrorDescriptionKey));
  }
  o << "Code: " << CFErrorGetCode(err)
    << " Domain: " << CFErrorGetDomain(err)
    << " Desc: " << desc.get();
  if(errorDesc) {
    o << "(" << errorDesc << ")";
  }
  return o;
}
