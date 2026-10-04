# SchedSim: A CPU Scheduler Simulator in x86-64 Assembly

![Language](https://img.shields.io/badge/language-x86--64%20GNU%20Assembly-blue)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Dependencies](https://img.shields.io/badge/libc-none-success)

SchedSim simulates five classic **CPU scheduling algorithms** and prints a clock-by-clock execution trace. It is written entirely in **x86-64 GNU Assembly (AT&T syntax)**. It doesn't link against libc: all I/O goes through raw Linux system calls, and all parsing, sorting and scheduling logic is done by hand at the register level.

---

## Highlights

- **Five scheduling algorithms:** FCFS, SJF, SRTF, Priority (preemptive) and Round Robin.
- **No standard library:** only the `read`, `write` and `exit` syscalls, called directly.
- **One generic parser** handles every input format. A field-count parameter (2, 3 or 4 fields) selects the format, and descriptors (`A-3-1`) are told apart from a bare RR quantum (`9`) by scanning ahead in the token.
- **Hand-written utilities:** an `atoi` routine, a stable bubble sort over 16-byte process records, and a ring-buffer queue for Round Robin.
- **Single-syscall output:** the whole trace is collected in a buffer and written to stdout with one `write` call.
- **Automated testing:** 28 test cases, a Python grader, and a GitHub Actions workflow that builds and grades every push.

---

## Supported algorithms

| Keyword | Algorithm | Preemptive | Input format | Notes |
|---|---|:---:|---|---|
| `FCFS` | First Come, First Served | ✗ | `ID-burst-arrival` | Runs processes in order of arrival. |
| `SJF`  | Shortest Job First | ✗ | `ID-burst` | All processes arrive at t = 0. |
| `SRTF` | Shortest Remaining Time First | ✓ | `ID-burst-arrival` | Re-evaluated every clock tick. |
| `PF`   | Priority First | ✓ | `ID-burst-arrival-priority` | Lower number means higher priority. Ties go to the shorter remaining time. |
| `RR`   | Round Robin | ✓ | `ID-burst ... quantum` | All processes arrive at t = 0. The quantum is the last token. |

Each character of the output is **one clock tick**. It is either the ID of the running process or `X` when the CPU is idle. In RR, a process that finishes before its quantum ends leaves the rest of that time slice idle, shown as `X`.

---

## Examples

```console
$ echo "FCFS F-11-4 V-7-0 U-10-4 N-4-9" | ./schedsim
VVVVVVVFFFFFFFFFFFUUUUUUUUUUNNNN

$ echo "SJF A-5 B-2 C-8" | ./schedsim
BBAAAAACCCCCCCC

$ echo "SRTF Y-8-21 H-46-7 T-32-22 C-8-3 M-40-0 G-34-34 I-43-26" | ./schedsim
MMMCCCCCCCCMMMMMMMMMMYYYYYYYYMMMMMMMMMMMMMMMMMMMMMMMMMMMTTTT...

$ echo "PF F-8-5-1 A-12-29-0 T-28-1-1" | ./schedsim
XTTTTFFFFFFFFTTTTTTTTTTTTTTTTAAAAAAAAAAAATTTTTTTT

$ echo "RR A-5 B-3 3" | ./schedsim
AAABBBAAX
```

---

## Architecture

```
          stdin
            │  read syscall (256-byte buffer)
            ▼
   ┌──────────────────┐
   │  _start          │  dispatch on 1st (and 2nd) character
   │  (schedsim.s)    │  F → FCFS, P → PF, R → RR, SJ → SJF, SR → SRTF
   └────────┬─────────┘
            ▼
   ┌──────────────────┐    parse_input / parse_one_process / atoi_advance
   │  <algo>_algo     │──► sort_processes (stable bubble sort on any field)
   │  fcfs/sjf/srtf/  │    append_char (writes one tick to output_buf)
   │  pf/rr.s         │
   └────────┬─────────┘
            ▼
   print_output: one write syscall ──► stdout, then exit syscall
```

**Process record layout (16 bytes each, in `proc_buf`):**

| Offset | Size | Field |
|---:|---:|---|
| 0  | 1 B | ID (single character) |
| 4  | 4 B | burst / remaining time |
| 8  | 4 B | arrival time |
| 12 | 4 B | priority |

Records are 16 bytes, so a record's address is just `index << 4`. `sort_processes` takes the field offset as a parameter, so the same routine sorts by arrival time, burst time or anything else.

### Project structure

```
src/
├── schedsim.s   # entry point, BSS buffers, algorithm dispatch, exit
├── parser.s     # input parsing, atoi, stable sort, output buffer and printing
├── fcfs.s       # First Come, First Served
├── sjf.s        # Shortest Job First
├── srtf.s       # Shortest Remaining Time First
├── pf.s         # Priority First (preemptive, SRTF tie-break)
└── rr.s         # Round Robin (ring-buffer queue)
test/
├── checker.py   # runs a single test case and compares the output
└── grader.py    # runs the full test suite and reports a score
test-cases/      # 28 input/expected-output pairs
.github/workflows/grade.yml   # CI: build, run and grade on every push
```

---

## Getting started

**Requirements:** Linux on x86-64, GNU `as` and `ld` (binutils), `make`, and Python 3 for the tests.

```bash
# Build
make

# Run (reads one line from stdin)
./schedsim
# or
echo "RR P-47 F-16 J-28 9" | ./schedsim

# Run every test case and save the outputs to my-outputs/
make testcases

# Grade against the expected outputs
make grade

# Check a single test case
python3 test/checker.py ./schedsim test-cases/input_00.txt out.txt test-cases/output_00.txt

# Clean build artifacts
make clean
```

---

## Limits

These limits come from the static buffer sizes:

- Input line: up to **256 bytes**
- Processes: up to **10** (`proc_buf` is 160 bytes)
- Output trace: up to **1023 ticks**
- Process IDs: one character each

---

## What is learned

- Writing a whole program in assembly without libc, from the syscall ABI up.
- Following the System V calling convention by hand (callee-saved registers, passing arguments in registers) across several source files linked together.
- Designing compact data layouts for fast address arithmetic.
- How preemptive and non-preemptive schedulers really differ when you have to simulate them tick by tick.
- Setting up CI for a low-level project with GitHub Actions and Docker.
