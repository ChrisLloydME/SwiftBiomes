#include "BiomeMapCBridge.h"

#include "../../CubiomesCore/cubiomes/generator.h"

#include <stdlib.h>
#include <string.h>

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
) {
    if (!output || width <= 0 || height <= 0 || outputCount < width * height) {
        return -1;
    }

    Generator generator;
    setupGenerator(&generator, minecraftVersion, 0);
    applySeed(&generator, dimension, (uint64_t)seed);

    Range range = { scale, x, z, width, height, y, 1 };
    int *cache = allocCache(&generator, range);
    if (!cache) {
        return -2;
    }

    int error = genBiomes(&generator, cache, range);
    if (error) {
        free(cache);
        return error;
    }

    memcpy(output, cache, (size_t)(width * height) * sizeof(int32_t));
    free(cache);
    return 0;
}
