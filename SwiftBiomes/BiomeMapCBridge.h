#ifndef BiomeMapCBridge_h
#define BiomeMapCBridge_h

#include <stdint.h>

int SBBiomesGenerateBiomeIDs(
    int32_t minecraftVersion,
    int64_t seed,
    int32_t dimension,
    int32_t scale,
    int32_t x,
    int32_t z,
    int32_t width,
    int32_t height,
    int32_t y,
    int32_t *output,
    int32_t outputCount
);

#endif
