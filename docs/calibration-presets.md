# Calibration presets

One 360° turn was recorded at each of the 13 spots on the room plan (`report/spots.svg`, panel a). Each spot has a fitted circle. Spots with similar circles share a preset, so three presets cover eleven spots, and two spots need their turn recorded again.

To use one, replace `MAG_OFFSET_X`, `MAG_OFFSET_Y` and `MAG_SCALE_Y` in `heading.h` with the three lines below, then rebuild and flash. Flash before the interview slot, not during it.

All errors here are heading error in degrees (root mean square / worst case) against the circle traced at that spot. They come from one turn per spot, and the presets were fitted to the same turns, so none of this is independently checked yet.

## The three presets

Preset A. Spots 1, 7, 8, 10 and 12 (spot 1 on the left, spots 8 and 10 beside the divider, spot 7 between the desks and spot 12 in the top right). It is the average of the fits at the five spots with a clean loop (1, 2, 3, 8 and 12).
```c
#define MAG_OFFSET_X      32    /* mG */
#define MAG_OFFSET_Y     153    /* mG */
#define MAG_SCALE_Y    1.013f
```

Preset B. Spots 2, 4, 5, 9 and 11 (spots 2 and 5 on the bottom row, spot 4 on the right edge, spot 9 beside the divider and spot 11 at the top between the desks). It is the fit at spot 2.
```c
#define MAG_OFFSET_X      -1    /* mG */
#define MAG_OFFSET_Y     173    /* mG */
#define MAG_SCALE_Y    1.025f
```

Preset C. Spot 3 only (between the right-hand desks, where the horizontal field is weak).
```c
#define MAG_OFFSET_X      69    /* mG */
#define MAG_OFFSET_Y     152    /* mG */
#define MAG_SCALE_Y    1.069f
```

## Which preset at which spot

| Spot | Preset | Expected error | `heading.h` today (25, 165, 0.943) | Loop quality |
|---|---|---|---|---|
| 1 | A | 1.4 / 3 | 1.7 / 5 | clean |
| 2 | B | 0 / 0 | 3.5 / 11 | clean |
| 3 | C | 0 / 0 | 11.2 / 23 | clean |
| 4 | B | 10.8 / 27 | 16.3 / 40 | irregular |
| 5 | B | 3.7 / 10 | 6.3 / 17 | irregular |
| 6 | none | not known | not known | turn not completed |
| 7 | A | 2.3 / 8 | 3.2 / 9 | irregular |
| 8 | A | 0.5 / 2 | 1.4 / 5 | clean |
| 9 | B | 10.6 / 33 | 13.8 / 43 | irregular, turn slightly short |
| 10 | A | 1.2 / 4 | 2.6 / 8 | irregular |
| 11 | B | 3.4 / 9 | 4.2 / 13 | irregular |
| 12 | A | 3.8 / 10 | 3.9 / 12 | clean |
| 13 | none | not known | not known | turn not completed |

Clean means a completed turn and a corrected field that varies by less than 10% around the loop. Irregular means the turn was completed but the loop was not a clean circle, so the reference it is judged against is less certain.

With the three presets the mean error over the eleven usable spots is 3.4° rms and the worst spot is 10.8° rms. One shared preset (offset 8, 159, scale 1.069) gives 5.8° mean and 13.5° worst. The preset now in `heading.h` gives 6.2° mean and 16.3° worst.

## What each spot looked like

| Spot | Circle centre x, y (mG) | Horizontal radius (mG) | Y scale | Mean vertical field (mG) | Loop spread |
|---|---|---|---|---|---|
| 1 | 34, 163 | 274 | 1.028 | 407 | 4.1% |
| 2 | -1, 173 | 287 | 1.025 | 489 | 8.4% |
| 3 | 69, 152 | 166 | 1.069 | 274 | 5.9% |
| 4 | -39, 184 | 194 | 1.273 | 592 | 24.6% |
| 5 | -24, 186 | 283 | 1.186 | 440 | 17.5% |
| 6 | 2, 241 | 134 | 0.659 | 552 | 38.6% (heading only swept 6°) |
| 7 | 18, 147 | 250 | 1.128 | 281 | 15.6% |
| 8 | 34, 155 | 304 | 0.990 | 626 | 7.9% |
| 9 | -66, 138 | 245 | 1.016 | 801 | 11.3% (swept 322°) |
| 10 | 32, 140 | 295 | 1.050 | 547 | 11.5% |
| 11 | 11, 190 | 226 | 1.043 | 416 | 13.4% |
| 12 | 23, 123 | 272 | 0.952 | 364 | 5.6% |
| 13 | -88, 112 | 94 | 1.321 | 529 | 34.5% (heading only swept 119°) |

Loop spread is the standard deviation of the corrected horizontal field around the turn as a share of its mean. A clean circle gives a few percent.

## What happens with the wrong preset

Across the 110 pairs of usable spots, a preset used at another spot gave a median error of 6.7° rms, 16° rms at the 90th percentile, and 27° rms at worst. The worst case for a single reading was 61°. Panel c of the figure shows the full grid.

## Notes

- Spots 6 and 13 need the turn recorded again. The heading only swept 6° and 119°, so the board was not turned through a full circle.
- Spots 4 and 9 are the weak ones. 4 has an irregular loop and a y scale of 1.27. 9 has the strongest vertical field (801 mG) and a centre 66 mG left of the others. Record both again, slowly and in place.
- Spot 3 has a weak horizontal field, about 166 mG against about 280 mG at the clean spots, so the same disturbance moves the heading more.
- Record a second turn at each spot you may use, so the presets can be checked against a turn they were not fitted to.
- Hold the board flat at the same height as in the recordings. Tilt costs about 1.7° of heading per degree.
- The vertical field alone cannot pick a spot. Several spots sit within about 50 mG of each other (1, 11 and 12 all read about 360 to 420 mG).
