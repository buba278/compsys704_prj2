/* Replay a serial log through the step counter on a PC, for tuning.
 *
 * Capture a log with ACC_DEBUG_PRINT set to 1 in main.c, then from the repo root:
 *   gcc -I COMSYS704/Projects/STM32L476JG-SensorTile/Applications/ALLMEMS1/Inc \
 *       tools/replay_steps.c \
 *       COMSYS704/Projects/STM32L476JG-SensorTile/Applications/ALLMEMS1/Src/step_counter.c \
 *       -lm -o replay_steps
 *   ./replay_steps walk20.txt
 * Lines that are not "ACC=x,y,z" (mg) are ignored.
 */
#include <stdio.h>
#include "step_counter.h"

int main(int argc, char **argv)
{
  FILE *f = argc > 1 ? fopen(argv[1], "r") : stdin;
  char line[128];
  int x, y, z;
  long n = 0;

  if (!f) {
    perror(argv[1]);
    return 1;
  }
  StepCounter_Init();
  while (fgets(line, sizeof line, f)) {
    if (sscanf(line, "ACC=%d,%d,%d", &x, &y, &z) != 3) {
      continue;
    }
    n++;
    if (StepCounter_Update(x, y, z)) {
      printf("%6.2f s  steps = %u\n", (double)n / STEP_COUNTER_SAMPLE_HZ,
             (unsigned)StepCounter_GetSteps());
    }
  }
  printf("%ld samples, %u steps\n", n, (unsigned)StepCounter_GetSteps());
  return 0;
}
