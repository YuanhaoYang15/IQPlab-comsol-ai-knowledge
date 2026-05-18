# Validation Prompts — Ring QPM Dispersion Module

Use these prompts to test whether an AI assistant understands Module 07.

---

## Prompt 1 — Mode selection

```text
In the Ring QPM workflow, can I simply use solnum = 1 for both 1550 nm and 775 nm modes during the whole wavelength sweep?
```

Expected answer pattern:

```text
No. The workflow should read all returned modes, filter physical modes, classify by TE/TM or component metrics, and then select the desired branch. COMSOL mode ordering can change with wavelength or geometry.
```

---

## Prompt 2 — Raw data preservation

```text
I changed the Q threshold after the sweep. Should I rerun COMSOL immediately?
```

Expected answer pattern:

```text
Not necessarily. If raw all-mode data were saved, the threshold should be changed in post-processing first. Rerun COMSOL only if the original sweep did not save enough modes or required fields.
```

---

## Prompt 3 — Dint units

```text
The script outputs D2_rad_s and D2_Hz. Which one should I use when plotting D2/2pi in MHz?
```

Expected answer pattern:

```text
Use D2_Hz directly and divide by 1e6 for MHz, or use D2_rad_s/(2*pi)/1e6. Do not mix angular frequency and ordinary frequency.
```

---

## Prompt 4 — SHG grid mismatch

```text
Why does the workflow compare mu_SH = 2*mu_IR rather than mu_SH = mu_IR?
```

Expected answer pattern:

```text
For second-harmonic generation, two IR photons map to one SH photon. Around the chosen center modes, the azimuthal mode-number offset in the SH band changes twice as fast as the IR offset, so the natural comparison is mu_SH = 2*mu_IR.
```

---

## Prompt 5 — rAverage correction

```text
The raw COMSOL neff and the corrected neff are different. Is this automatically an error?
```

Expected answer pattern:

```text
Not automatically. In the ring or axisymmetric model, the effective radius used by COMSOL may differ from the intended physical radius. The workflow stores rAverage and a scale factor so the correction can be audited. The model convention must be verified before trusting either value.
```
