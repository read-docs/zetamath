/// A string-seeded Mulberry32 stream that reproduces `web/src/engine/rng.ts` bit for bit.
///
/// JavaScript does this arithmetic on 32-bit integers (`Math.imul`, `|0`, `>>>`) while Dart ints
/// are 64-bit, so every step is truncated back to 32 bits by hand.
double Function() createRng(String seed) {
  var state = _i32(2166136261);
  // charCodeAt is a UTF-16 code unit, which is what codeUnits yields (not runes).
  for (final unit in seed.codeUnits) {
    state = _imul(state ^ unit, 16777619);
  }
  return () {
    state = _i32(state + 0x6d2b79f5);
    var t = _imul(state ^ _ushr(state, 15), 1 | state);
    t = t ^ _i32(t + _imul(t ^ _ushr(t, 7), 61 | t));
    return (_i32(t ^ _ushr(t, 14)) & 0xFFFFFFFF) / 4294967296;
  };
}

int _i32(int x) => x.toSigned(32);

/// JavaScript `x >>> n` for a 32-bit value.
int _ushr(int x, int n) => (x & 0xFFFFFFFF) >> n;

/// JavaScript `Math.imul`: the low 32 bits of the product, as a signed int.
/// Split into 16-bit halves so no intermediate product overflows 64 bits.
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
  return _i32(al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16));
}
