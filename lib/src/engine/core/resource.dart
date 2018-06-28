import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

class ResourceSet<T> {
  final Map<String, _Tag<T>> _tags = {};
  final Map<String, _Resource<T>> _resources = {};

  // TODO: Evict old queries from the cache if it gets too large.
  final Map<_QueryKey, _ResourceQuery<T>> _queries = {};

  bool get isEmpty => _resources.isEmpty;

  bool get isNotEmpty => _resources.isNotEmpty;

  Iterable<T> get all => _resources.values.map((resource) => resource.object);

  void add(String name, T object, int depth, double frequency,
      [String tagNames]) {
    if (_resources.containsKey(name)) {
      throw new ArgumentError('Already have a resource named "$name".');
    }

    var resource = new _Resource(object, depth, frequency);
    _resources[name] = resource;

    if (tagNames != null) {
      for (var tagName in tagNames.split(" ")) {
        var tag = _tags[tagName];
        if (tag == null) throw new ArgumentError('Unknown tag "$name".');
        resource._tags.add(tag);
      }
    }
  }

  void addUnnamed(T object, int depth, double frequency, [String tagNames]) {
    return add(
        _resources.length.toString(), object, depth, frequency, tagNames);
  }

  /// Given a string like "a/b/c d/e" defines tags for "a", "b", "c", "d", and
  /// "e" (if not already defined) and wires them up such that "c"'s parent is
  /// "b", "b"'s is "a", and "e"'s parent is "d".
  void defineTags(String paths) {
    for (var path in paths.split(" ")) {
      _Tag<T> parent;
      _Tag<T> tag;
      for (var name in path.split("/")) {
        tag = _tags[name];
        if (tag == null) {
          tag = new _Tag<T>(name, parent);
          _tags[name] = tag;
        }

        parent = tag;
      }
    }
  }

  /// Returns the resource with [name].
  T find(String name) {
    var resource = _resources[name];
    if (resource == null) throw new ArgumentError('Unknown resource "$name".');
    return resource.object;
  }

  /// Returns the resource with [name], if any, or else `null`.
  T tryFind(String name) {
    var resource = _resources[name];
    if (resource == null) return null;
    return resource.object;
  }

  double frequency(String name) {
    var resource = _resources[name];
    if (resource == null) throw new ArgumentError('Unknown resource "$name".');
    return resource.frequency;
  }

  /// Returns whether the resource with [name] has [tagName] as one of its
  /// immediate tags or one of their parents.
  bool hasTag(String name, String tagName) {
    var resource = _resources[name];
    if (resource == null) throw new ArgumentError('Unknown resource "$name".');

    var tag = _tags[tagName];
    if (tag == null) throw new ArgumentError('Unknown tag "$tagName".');

    return resource._tags.any((thisTag) => thisTag.contains(tag));
  }

  /// Gets the names of the tags for the resource with [name].
  Iterable<String> getTags(String name) {
    var resource = _resources[name];
    if (resource == null) throw new ArgumentError('Unknown resource "$name".');
    return resource._tags.map((tag) => tag.name);
  }

  bool tagExists(String tagName) => _tags.containsKey(tagName);

  /// Chooses a random resource in [tagName] for [depth].
  ///
  /// All resources of child tags of [tagName]. For example, given tag
  /// path "equipment/weapon/sword", if [tagName] is "weapon", this will permit
  /// resources tagged "weapon" or "sword", with equal probability.
  ///
  /// Resources of in parent tags are also possible, but with less probability.
  /// So in the above example, anything tagged "equipment" is included but rare.
  ///
  /// May return `null` if there are no resources with [tagName].
  T tryChoose(int depth, String tagName) {
    assert(tagName != null);
    var goalTag = _tags[tagName];
    assert(goalTag != null);

    return _runQuery(goalTag.name, depth, (resource) {
      var tag = goalTag;
      var scale = 1.0;

      // Walk up the tag chain, including parent tags.
      while (tag != null) {
        for (var resourceTag in resource._tags) {
          if (resourceTag.contains(tag)) return scale;
        }

        // Parent tags are less likely than the preferred tag.
        tag = tag.parent;
        // TODO: Allow callers to tune this?
        scale /= 10.0;
      }

      return 0.0;
    });
  }

  /// Chooses a random resource at [depth] from the set of resources whose tags
  /// match at least one of [tags].
  ///
  /// For example, given tag path "equipment/weapon/sword", if [tags] is
  /// "weapon", this will permit resources tagged "weapon" or "equipment", but
  /// not "sword".
  T tryChooseMatching(int depth, Iterable<String> tags) {
    var tagObjects = tags.map((name) {
      var tag = _tags[name];
      if (tag == null) throw new ArgumentError('Unknown tag "$name".');
      return tag;
    });

    var tagNames = tags.toList();
    tagNames.sort();

    return _runQuery("${tagNames.join('|')} (match)", depth, (resource) {
      for (var resourceTag in resource._tags) {
        if (tagObjects.any((tag) => tag.contains(resourceTag))) return 1.0;
      }

      return 0.0;
    });
  }

  T _runQuery(String name, int depth, double scale(_Resource<T> resource)) {
    // Reuse a cached query, if possible.
    var key = new _QueryKey(name, depth);
    var query = _queries[key];
    if (query == null) {
      var resources = <_Resource<T>>[];
      var chances = <double>[];
      var totalChance = 0.0;

      // Determine the weighted chance for each resource.
      for (var resource in _resources.values) {
        var chance = scale(resource);
        if (chance == 0.0) continue;

        chance *= resource.frequency * _depthScale(resource.depth, depth);

        // The depth scale is so narrow at low levels that highly out of depth
        // items can have a 0% chance of being generated due to floating point
        // rounding. Since that breaks the query chooser, and because it's a
        // little sad, always have some non-zero minimum chance.
        chance = math.max(0.0000001, chance);

        totalChance += chance;
        resources.add(resource);
        chances.add(totalChance);
      }

      query = new _ResourceQuery<T>(depth, resources, chances, totalChance);
      _queries[key] = query;
    }

    return query.choose();
  }

  /// Gets the probability adjustment for choosing a resource with [depth] at
  /// a goal of [targetDepth].
  ///
  /// This is based on a normal distribution, with some tweaks. Unlike the
  /// real normal distribution, this does *not* ensure that all probabilities
  /// sum to zero. We don't need to since we normalize separately.
  ///
  /// Instead, this always returns `1.0` for the most probable [depth], which is
  /// when it's equal to [targetDepth]. On either side of that, we have a bell
  /// curve. The curve widens as you go deeper in the dungeon. This reflects
  /// the fact that encountering a depth 4 monster at depth 1 is a lot more
  /// dangerous than a depth 54 monster at depth 51.
  ///
  /// The curve is also asymmetric. It widens out more quickly on the left.
  /// This means that as you venture deeper, weaker things you've already seen
  /// "linger" and are more likely to appear than out-of-depth *stronger*
  /// things are.
  ///
  /// https://en.wikipedia.org/wiki/Normal_distribution
  double _depthScale(int resourceDepth, int targetDepth) {
    var relative = (resourceDepth - targetDepth).toDouble();
    double deviation;
    if (relative <= 0.0) {
      // As you get deeper in the dungeon, the probability curve widens so that
      // you still find weaker stuff fairly frequently.
      deviation = 1.0 + targetDepth * 0.2;
    } else {
      deviation = 0.7 + targetDepth * 0.1;
    }

    return math.exp(-0.5 * relative * relative / (deviation * deviation));
  }
}

class _Resource<T> {
  final T object;
  final int depth;

  final double frequency;
  final Set<_Tag<T>> _tags = new Set();

  _Resource(this.object, this.depth, this.frequency);
}

class _Tag<T> {
  final String name;
  final _Tag<T> parent;

  _Tag(this.name, this.parent);

  /// Returns `true` if this tag is [tag] or one of this tag's parents is.
  bool contains(_Tag<T> tag) {
    for (var thisTag = this; thisTag != null; thisTag = thisTag.parent) {
      if (tag == thisTag) return true;
    }

    return false;
  }
}

/// Uniquely identifies a query.
class _QueryKey {
  final String name;
  final int depth;

  _QueryKey(this.name, this.depth);

  int get hashCode => name.hashCode ^ depth.hashCode;

  bool operator ==(other) {
    assert(other is _QueryKey);
    return name == other.name && depth == other.depth;
  }

  String toString() => "$name ($depth)";
}

/// A stored query that let us quickly choose a random weighted resource for
/// some given criteria.
///
/// The basic process for picking a random resource is:
///
/// 1. Find all of the resources that could be chosen.
/// 2. Calculate the chance of choosing each item.
/// 3. Pick a random number up to the total chance.
/// 4. Find the resource whose chance contains that number.
///
/// The first two steps are quite slow: they involve iterating over all
/// resources, allocating a list, etc. Fortunately, we can reuse the results of
/// them for every call to [tryChoose] or [tryChooseMatching] with the same
/// arguments.
///
/// This caches that state.
class _ResourceQuery<T> {
  final int depth;
  final List<_Resource<T>> resources;
  final List<double> chances;
  final double totalChance;

  _ResourceQuery(this.depth, this.resources, this.chances, this.totalChance);

  /// Choose a random resource that matches this query.
  T choose() {
    if (resources.isEmpty) return null;

    // Pick a point in the probability range.
    var t = rng.float(totalChance);

    // Binary search to find the resource in that chance range.
    var first = 0;
    var last = resources.length - 1;

    while (true) {
      var middle = (first + last) ~/ 2;
      if (middle > 0 && t < chances[middle - 1]) {
        last = middle - 1;
      } else if (t < chances[middle]) {
        return resources[middle].object;
      } else {
        first = middle + 1;
      }
    }
  }

  void dump(_QueryKey key) {
    print(key);
    for (var i = 0; i < resources.length; i++) {
      var chance = chances[i];
      if (i > 0) chance -= chances[i - 1];
      var percent =
          (100.0 * chance / totalChance).toStringAsFixed(5).padLeft(8);
      print("$percent% ${resources[i].object}");
    }
  }
}
