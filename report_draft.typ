#import "template.typ": ieee

// Group report for Deliverable 5. Limits from the brief: 4 pages, this template, with a
// description of the algorithms, a performance analysis and a discussion of limitations.
// Due 19 Oct 5pm on Canvas. Export the PDF as project2_groupXX.pdf.
// Highlighted text marks content that still needs data or a decision.

#show: ieee.with(
  title: [Step Counting and Heading on a SensorTile],
  authors: (
    (
      name: "Christian Motta",
      dept: "Dept. of Electrical, Computer and Software Engineering",
      org: "The University of Auckland",
      location: "Auckland, New Zealand · cmot464 / 513090963",
    ),
    (
      name: "Tania Pan",
      dept: "Dept. of Electrical, Computer and Software Engineering",
      org: "The University of Auckland",
      location: "Auckland, New Zealand · tpan328 / TODO",
    ),
  ),
  abstract: [This report describes a pedestrian tracker that counts steps and reports heading using only the accelerometer and magnetometer of a SensorTile. The heading is relative to the direction faced at power on. The main finding is that a magnetometer heading is only as accurate as its calibration, and a calibration only holds close to the spot where it was made. Turning on the calibrated spot gave a heading within 6° of the expected angle at every stop. Using the calibration from one spot at another gave a median error of 5.0° root mean square (rms) across five clean spots in the lab and up to 15.8° rms, and walking across the lab broke the heading completely because the magnetic field varied by more than the Earth's own. The step counter is a peak detector on the smoothed vertical acceleration with an adaptive threshold. It counted 58 steps for 60 over three walks with 180° turns, counted hard heel strikes exactly and gave one false step in 10.5 s of shaking while standing still.],
  keywords: ("pedestrian dead reckoning", "step detection", "heading", "magnetometer", "SensorTile"),
)

= Introduction
AICorp wants a wearable that reports the step count and heading of a worker inside a factory. The prototype runs on a SensorTile @st_um2101, which carries an LSM303AGR accelerometer and magnetometer @st_lsm303agr and sends its results to a phone over Bluetooth Low Energy (BLE). The brief allows only those two sensors, so there is no gyroscope. The board is held flat in the hand and runs from its battery.

The step count and a heading from 0° to 359° are scored in a lab session. The heading is relative to the direction faced at power on and increases clockwise. Step based dead reckoning splits into counting steps and finding direction @jin2011, and a magnetometer needs calibration for the board's own magnetic parts and for nearby metal @st_an4825.

The heading worked well when the board was calibrated on the spot where it was used. The same calibration gave errors of up to 16° a few metres away, because the magnetic field in the lab changes with position by more than the Earth's own field. A worker walking through a factory crosses exactly these changes, so a heading that is right at one workstation can be wrong at the next. That makes the calibration location the main constraint on the design, and most of this report is about how the heading is calibrated and how far one calibration can be trusted.

= System Overview
The system is a sensor loop on the microcontroller, two processing modules and a web tool used for calibration and logging.

== Hardware and Firmware
The microcontroller is an STM32L476 on the SensorTile. The accelerometer and the magnetometer are separate parts of the LSM303AGR, each with its own chip select. They are read over the board's second Serial Peripheral Interface (SPI) peripheral, which is shared with the other motion and pressure sensors on the board. The bus runs in three wire mode, where one data line carries data in both directions. The LSM303AGR also offers an inter-integrated circuit (I2C) interface, but the course starter code provides the SPI read and write functions, so SPI was used. The I2C interface of every sensor on the bus is switched off with a register bit, because the sensors stop answering over SPI otherwise. Block data update is enabled on both sensors so that the two bytes of a reading always come from the same sample.

The accelerometer runs at 100 Hz with a ±4 g range and 12 bit resolution. The magnetometer runs at 100 Hz in continuous mode at 1.5 mG per count (mG is milligauss). A timer sets a flag every 20 ms, so the main loop runs at 50 Hz. Each pass reads both sensors, updates the step counter and the heading module, and stores the results. The BLE service sends steps and heading in the fields of the gyroscope characteristic, each multiplied by 10, at 20 Hz. Steps multiplied by 10 travels in a signed 16 bit field, so the count wraps after about 3270 steps. The step counter and the heading module make no hardware calls, so both build and run on a PC and were tested there before flashing.

== Development Tools
A web page, SensorTile Live (@fig-tool), reads the same BLE packet as the marking app and was used to see what the board was doing and to record data. Its compass and trail views show the heading and a dead reckoning path. The calibration view draws the raw and corrected magnetometer circle while the board is turned and gives the numbers to copy into the firmware. The step view plots the filtered acceleration against an adjustable threshold, and the record view saves labelled readings as CSV files. Every recording in this report came from that page, and offline scripts produced the tables and figures. The screenshots were taken in the page's demo mode, which replays simulated data, so they show the layout and not measured results.

#figure(
  image("webtool.png", width: 100%),
  placement: top,
  scope: "parent",
  caption: [SensorTile Live in demo mode. Top row from the left: compass, calibration circle (raw in grey and corrected in black) and dead reckoning trail. Bottom row from the left: step signal with its threshold, and the CSV recorder.],
) <fig-tool>

= Step Counting
Each step lifts and drops the body, so a board held in the hand sees one rise and fall in vertical acceleration per step. The step counter finds these peaks in the accelerometer signal, which is the most common approach to step detection @jin2011. The step count also matters for tracking position, because dead reckoning estimates distance walked as the number of steps times a step length, so every missed or extra step puts the estimated position about one step length away from where the person really is.

== Algorithm <sec-step-alg>
The detector in `step_counter.c` runs once per pass of the 50 Hz loop and takes the acceleration in mg. It has five stages.

+ Vertical axis. Only the z reading is used. The board is held flat, so gravity and the vertical bounce of walking both lie along z, while sideways sway and shaking show up mostly on x and y.
+ Gravity removal. A slow exponential moving average of z ($alpha = 0.02$, a time constant of 1 s) tracks the steady 1 g of gravity and is subtracted, which leaves a signal centred on zero. This also cancels any offset in the sensor. The average starts at the first reading, so power on does not look like a step.
+ Smoothing. A moving average over 8 samples (160 ms) keeps 76% to 91% of the bounce of walking at 1.5 Hz to 2.5 Hz, but only 24% to 45% of shaking at 4 Hz to 5 Hz. It also merges the jolt of a heel strike with its rebound, which would otherwise make two peaks for one step.
+ Peak detection. The detector arms when the signal rises above a threshold and counts a step when it then falls back through zero. The threshold is a quarter of the recent peak to peak amplitude, which follows each new step with a weight of 0.25, so it scales with how hard the person walks. It never drops below 110 mg, so standing still does not count.
+ Timing. A step is only counted if at least 300 ms have passed since the last one, which limits the count to about 3.3 steps per second, faster than a person walks. After 2 s with no step the amplitude is forgotten and the threshold falls back to 110 mg, so a slow first step after a pause is not missed because the threshold is still set for brisk walking.

The module was tuned on a PC by replaying logged readings through the same C file (`tools/replay_steps.c`), and the step view of the web page (@fig-tool) plots the filtered signal against the threshold live.

== Design Decisions
The detector reached its final form in four versions, each tested on the board (@tab-steps). The first used the size of the whole acceleration vector, $sqrt(a_x^2 + a_y^2 + a_z^2)$, with a 5 sample average and an 80 mg floor. The size does not depend on how the board is held, which is why it is common in phone based step counters. It counted walks well but also counted steps when the board was shaken or the holder laughed while standing still, because much of that movement is horizontal and the size picks it up. The second version used only z and raised the floor to 130 mg. That reduced the false steps but did not remove them, and it counted hard heel strikes twice. The third lengthened the average from 5 to 8 samples to filter out faster shaking and heel strike rebounds. Because the longer average also shrinks real steps by 10% to 25%, the final version lowered the floor to 110 mg to keep a margin for soft steps. Using only z makes the counter depend on the board being held flat, as discussed under Limitations.

== Results
Each result is the change in the step count sent over BLE, logged by the web page at about 20 Hz. The first version was tested with five 10 step walks. The later versions were tested with walks of 10 steps, a 180° turn on the spot and 10 more steps, at a normal pace of about 0.68 s per step, and with a walk of 5 steps, a turn and 5 steps landing hard on the heel. The board was held by the person recording, who had to turn to the side to stop the recording at the end.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: left,
    [Version], [Walks], [Heel strike], [False steps],
    [1: $|a|$, 5 samples, 80 mg], [52 / 50], [--], [6 in 17.4 s],
    [2: z, 5 samples, 130 mg], [81 / 80], [14 / 10], [4 in 14.6 s],
    [3: z, 8 samples, 130 mg], [58 / 60], [10 / 10], [1 in 9.4 s],
    [4: z, 8 samples, 110 mg], [58 / 60], [10 / 10], [1 in 10.5 s],
  ),
  caption: [Steps counted against steps taken for each version of the detector, given as the signal used, the length of the average and the floor. False steps were counted while standing still with the board shaken, laughing, or both.],
) <tab-steps>

The final version counted 58 steps for 60 over three walks (−3.3%), counted the heel strike walk exactly, and gave one false step in 10.5 s of laughing and shaking, against six in 17.4 s for the first version. The 180° turns on the spot, each 2.5 s to 4 s long, never added a step, and neither did turning to stop the recording, because the board stays flat while turning and z barely changes.

The errors that remain are small. One walk counted an extra step 0.3 s into the recording, almost 2 s before the walk began, from the movement of starting the recording. The same walk missed a step near its end, so it still totalled 20. Another walk missed two steps 2 s to 5 s into its first leg, where the gaps between counted steps were 1.2 s to 1.3 s instead of the usual 0.6 s to 0.7 s. Version 3 missed two steps at the same point of the matching walk, and lowering the floor from 130 mg to 110 mg did not recover them. The most likely cause is the adaptive part of the threshold, which rises after a few strong first steps and then misses a softer one. The 20 Hz logs do not contain the filtered signal, so this was not confirmed.

= Heading
Heading comes from the magnetometer alone. This chapter explains how the angle is found and calibrated, and why some options were left out.

== Finding the Heading
A magnetometer measures the direction of the magnetic field in the frame of the board. Turn the board clockwise on the spot and the field appears to turn anticlockwise by the same angle, so the angle of the field in the board frame gives the direction the board faces. The firmware takes the two horizontal readings, finds the angle between them with the arctangent function (atan2) and flips the sign so that a clockwise turn makes the heading rise. The sign flip depends on how the chip is mounted and was set by turning the board and watching the output.

The marking asks for a heading relative to the start direction, so the Earth's north does not matter. For 1.5 s after power on the board is held still, and the direction it reads in that time becomes zero. The readings are averaged before the angle is taken, because averaging angles directly fails at the wrap, where 359° and 1° average to 180°. After that, every heading is the angle minus the zero direction, wrapped to 0° to 359° and rounded to whole degrees. On a recorded turn, the same calculation in the web page matched the device heading to 0.3° rms.

== Calibration <sec-cal>
The raw readings are not centred on zero. Turn a flat board slowly through one full circle and the horizontal readings should trace a circle around zero, but two effects distort it @st_an4825. Magnetised parts on the board, such as the battery, add a constant push in one direction, which moves the circle off centre. This is called hard iron. Nearby metal bends the field and squashes the circle into an ellipse, which is called soft iron. The firmware undoes the first with an offset on each axis and the second, to first order, with one stretch factor on y.

Both values come from one slow 360° turn. Each offset is the middle of the smallest and largest reading on that axis, and the y stretch is the ratio of the x width to the y width. The board has no button, so the values are constants in `heading.h` and change by reflashing.

== Design Decisions
Three options were left out. A check that freezes the heading when the field strength leaves a baseline band @yan2022 was built and then removed, because it could freeze the heading in the middle of a turn, which is the scored case. The gyroscope on the SensorTile was left out because the brief names only the accelerometer and magnetometer.

The heading is also not oversampled or smoothed. The sensors already run at 100 Hz and the loop reads the latest sample every 20 ms. Running the heading at 100 Hz and averaging pairs of samples would lower random noise by a factor of 1.4 at most, and the heading at rest varies by only 2° to 3°, some of which is likely hand movement. The errors that matter come from the field changing with position and from tilt (@sec-perf), and averaging removes neither. A longer average would remove more jitter but would delay the output by half its length during a turn. The step counter is also tuned to the 50 Hz loop, so a faster loop would change its behaviour too.

= Heading Performance <sec-perf>
This chapter answers three questions. How accurate is the heading on the spot where it was calibrated, how far does a calibration carry across the lab, and what happens while walking. All results come from recordings of the device output at 20 Hz, the same data the marking app receives. Angles were set by hand against crude markers around the lab, so part of every error belongs to the reference.

== On the Calibrated Spot
With the calibration made at the same spot, the board read 2°, 96°, 184°, 275° and 357° at nominal stops of 0°, 90°, 180°, 270° and 360°. The errors were +2°, +6°, +4°, +5° and −3°, so never above 6°. At rest the heading varied by 2° to 3°. This is the best case, and the next section shows that it does not hold elsewhere.

Height and tilt both matter. An earlier calibration made on the floor traced a circle of about 570 mG radius, against about 300 mG at hand height, so the floor appears to add about 300 mG of horizontal field. Used at hand height it gave 4° to 6° rms error (10° to 12° at worst), so every later calibration was made at hand height. Tilting the board 15° forward moved the heading by about 25°, roughly 1.7° per degree of tilt. In the lab the vertical field (274 mG to 626 mG at the clean spots) is larger than the horizontal field (166 mG to 304 mG), so tilt leaks a large vertical component into the horizontal readings.

== Calibration Across the Lab
@fig-spots shows the lab plan with 13 spots chosen as likely interview positions, and one 360° turn recorded at each, held at hand height. Two turns were not completed and six loops were irregular, so the analysis uses the five spots with a clean loop (1, 2, 3, 8 and 12), where the corrected horizontal field varied by 4% to 8% around the turn. The circle fitted at each of them is in @tab-spots. Even across these five spots the circle centre moves by up to 70 mG in x and 50 mG in y, and the horizontal radius changes by almost a factor of two.

#figure(
  image("spots.svg", width: 100%),
  placement: top,
  scope: "parent",
  caption: [Lab plan with the 13 spots coloured by shared preset (a), and the fitted circle centre at each spot with a completed turn (b). Only the five spots with a clean loop are used in the analysis.],
) <fig-spots>

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: left,
    [Spot], [Centre x, y (mG)], [Radius (mG)], [Y scale], [Vertical (mG)], [Spread],
    [1], [34, 163], [274], [1.028], [407], [4.1%],
    [2], [−1, 173], [287], [1.025], [489], [8.4%],
    [3], [69, 152], [166], [1.069], [274], [5.9%],
    [8], [34, 155], [304], [0.990], [626], [7.9%],
    [12], [23, 123], [272], [0.952], [364], [5.6%],
  ),
  caption: [Circle fitted to the turn at each clean spot. Radius is the mean horizontal radius, vertical is the mean vertical field, and spread is the variation of the corrected horizontal field around the turn.],
) <tab-spots>

Using the calibration from one spot at another shows what this costs. Across the 20 pairs of these five spots, the median error was 5.0° rms, the worst pair was 15.8° rms (the calibration from spot 2 used at spot 3) and the worst single reading was 33° out. Spot 3 was the most sensitive because its horizontal field was the weakest, so the same offset error is a larger angle. Each error is the difference between the heading from the other spot's calibration and the heading from the circle fitted at that spot, with the constant offset removed.

Spots with similar circles can share a calibration. Three presets cover the clean spots, with preset A (the average of the five fits) for spots 1, 8 and 12, preset B (the fit at spot 2) and preset C (the fit at spot 3). They held the error at those spots to between 0° and 3.8° rms. These are the turns the presets were fitted from, so the figures show what a good calibration can reach and do not validate it on a new turn.

== Heading While Walking
As a stress test, two walks of 80 steps each went round the whole lab in a rough rectangle with a calibration from a single spot. The heading never settled into four straight legs. Dead reckoned with 0.7 m per step, the paths ended 7.2 m and 10.0 m from the start of a loop that should have closed. The horizontal field strength ranged from 56 mG to 699 mG during the walks, against a steady 580 mG at the spot where the calibration was made. Tilt averaged 6° to 9° and reached 23°, which adds wobble but does not explain a swing of that size.

Walking a straight line while facing one way gave a heading standard deviation of 120° to 135°. At the same step number the two rectangle walks differed by 15° rms (62° at worst), so part of the error repeats with position and part is noise. The lab's field, not the walking motion, is what breaks the heading.

= Limitations
The heading is valid only near the spot where it was calibrated. The main limits are as follows.

- Position. The field changes by more than the Earth's whole field across the lab, so no single calibration holds everywhere. The calibration from another clean spot gave up to 15.8° rms of error.
- Height. A calibration made on the floor is about 10° out at hand height.
- Fixed values. The board has no button and cannot calibrate itself, so the values are fixed in the firmware and the board is reflashed to change spot.
- Tilt. Heading error grows by about 1.7° per degree of tilt, and the firmware assumes the board is flat.
- Soft iron. One scale on y cannot correct a rotated ellipse. A full ellipse fit would move the heading by up to 3° at spot 1 and 8° at spot 2.
- No gyroscope. Nothing holds the heading while walking.
- Start up. The board must stay still for 1.5 s, because movement in that time shifts every later heading by the same amount.
- Steps. The step counter also assumes a flat board. Tilted by an angle $theta$, only $cos theta$ of the vertical bounce reaches z, so steps shrink towards the 110 mg floor, and a board carried in a pocket or swinging in the hand would miss steps. Soft or very slow steps can stay under the floor. Vertical shaking at walking pace still counts (one false step in 10.5 s), a soft step after a few strong ones can fall under the adaptive threshold (two missed in one walk), and movement just before a walk can add one step. The 300 ms gate caps the count at about 3.3 steps per second, so running is undercounted.

= Future Improvements
The largest gain would come from removing the dependence on the calibration spot, so most of these target it.

- Calibrate at the spot of use. A button or a first turn after power on would set the offsets where the board is used and remove the need to reflash.
- Consider a gyroscope. The brief does not ask for a gyroscope which does not depend on the magnetic field. Adding it would likely hold the heading while walking.
- Fit the full ellipse. A rotated ellipse fit corrects the soft iron error that one y scale leaves.
- Revisit tilt compensation. A version that projects the field onto the horizontal plane using the accelerometer gravity direction corrected 15° of pitch and roll to 0° on synthetic data, but made the heading very jittery on the board. The cause was not found. Noise in the accelerometer reading is one possibility to check, which a low pass filter on it would reduce.
- Steps in any orientation. Projecting the acceleration onto the gravity direction from the slow average, instead of using z, would keep the vertical bounce at any tilt. Counting only once two or three steps arrive at a regular rhythm would also reject single shakes.

= Conclusion
A magnetometer only heading reached 6° at every stop when turning on the spot where it was calibrated, and failed while walking across the lab. The lab's field varies by more than the Earth's own, so the calibration spot sets the error. Among five clean spots, the calibration from another spot gave a median error of 5.0° rms and up to 15.8° rms, so the board should be calibrated where it will be used. The step counter's first version counted walks well but also counted shaking as steps. Using only the vertical axis and a longer average removed most of those false steps and the double counts from hard heel strikes, at the cost of needing the board held flat. The final version counted 58 of 60 steps, ignored turns on the spot and gave one false step in 10.5 s of shaking.

#bibliography("refs.bib", style: "ieee")
