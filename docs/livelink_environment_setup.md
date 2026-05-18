# LiveLink for MATLAB: Environment Setup

## Purpose

This note explains the basic environment setup required before using MATLAB LiveLink for COMSOL.

It covers:

- the relationship between the COMSOL installation root and the MATLAB installation root,
- how COMSOL and MATLAB communicate through a client-server connection,
- how to start COMSOL with MATLAB,
- how to manually connect MATLAB to a COMSOL server,
- how the first-time username and password setup works,
- common setup problems.

This note should be read before running any MATLAB LiveLink script.

## 1. Basic Architecture

LiveLink for MATLAB uses a client-server architecture.

In a typical local workflow:

- MATLAB acts as the client.
- COMSOL Multiphysics runs a local server process.
- MATLAB sends commands to the COMSOL server.
- The COMSOL server owns the model object and performs geometry building, meshing, solving, and result evaluation.

The communication is usually local, on the same computer.

The default COMSOL server port is usually:

```text
2036
```

If this port is already in use, COMSOL may use the next available port, such as:

```text
2037
2038
...
```

## 2. COMSOL Root Directory and MATLAB Root Directory

There are two important installation paths.

### COMSOL root directory

This is the COMSOL installation folder.

Typical Windows example:

```text
C:\Program Files\COMSOL\COMSOL63\Multiphysics
```

The LiveLink MATLAB interface files are usually located in:

```text
<COMSOL_ROOT>\mli
```

For example:

```text
C:\Program Files\COMSOL\COMSOL63\Multiphysics\mli
```

MATLAB may need this folder in its path when manually connecting to a COMSOL server.

### MATLAB root directory

This is the MATLAB installation folder.

Typical Windows examples:

```text
C:\Program Files\MATLAB\R2023b
C:\Program Files\MATLAB\R2024a
C:\Program Files\MATLAB\R2024b
```

COMSOL needs to know the MATLAB root directory when launching or calling MATLAB.

## 3. Two Directions of Path Configuration

There are two different path relationships.

### Direction 1: COMSOL needs to know MATLAB

This is needed when COMSOL starts MATLAB or calls external MATLAB functions.

In COMSOL Desktop, check the LiveLink for MATLAB preference page. The exact menu name may depend on the COMSOL version, but it is typically located under:

```text
File → Preferences → LiveLink Connections → LiveLink for MATLAB
```

Set the MATLAB installation folder to the correct MATLAB root directory.

On Windows, after selecting the MATLAB folder, click:

```text
Register MATLAB as COM Server
```

Then click OK and restart COMSOL Desktop.

### Direction 2: MATLAB needs to know COMSOL

This is needed when MATLAB connects manually to a COMSOL server.

In MATLAB, add the COMSOL LiveLink folder to the MATLAB path:

```matlab
addpath('C:\Program Files\COMSOL\COMSOL63\Multiphysics\mli');
```

Then connect to a running COMSOL server using:

```matlab
mphstart
```

or, if the server is using a specific port:

```matlab
mphstart(2036)
```

For a remote server:

```matlab
mphstart('server_ip_or_hostname', 2036)
```

If username and password are required:

```matlab
mphstart('server_ip_or_hostname', 2036, 'username', 'password')
```

Do not commit real usernames or passwords to this repository.

## 4. Recommended First-Time Startup Method

For most local Windows users, the recommended method is to start MATLAB through the COMSOL shortcut:

```text
Start Menu → COMSOL Multiphysics → COMSOL Multiphysics with MATLAB
```

This automatically starts both:

- a COMSOL Multiphysics server,
- a MATLAB session connected to that server.

After MATLAB opens, test the connection with:

```matlab
import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(true)
mphtags
```

If no error appears, the LiveLink connection is active.

## 5. First-Time Username and Password Setup

The first time COMSOL Multiphysics with MATLAB is started, COMSOL may ask for a username and password.

Important notes:

- This is the username/password for the local COMSOL-MATLAB client-server connection.
- It is not necessarily the Windows system username/password.
- It is not the GitHub password.
- It is not necessarily the COMSOL Access account password.
- It is saved in the local user preference file after the first setup.
- Usually, the same user does not need to enter it again on the same machine.

Recommended lab practice:

```text
Choose a simple local username and a non-sensitive password.
Do not reuse important institutional or personal passwords.
Do not write this password into scripts, notes, or GitHub files.
```

If the login information needs to be reset, start COMSOL with the login reset flag:

```text
-login force
```

For example, from a system command prompt:

```text
comsol mphserver matlab -login force
```

The exact command may depend on the COMSOL version and the system PATH configuration.

## 6. Manual Connection Workflow

Sometimes MATLAB is started normally first, and the COMSOL server is started separately.

In that case, the workflow is:

1. Start COMSOL Multiphysics Server.
2. Check the port number displayed in the COMSOL server window.
3. Start MATLAB.
4. Add the COMSOL LiveLink `mli` directory to the MATLAB path.
5. Run `mphstart`.

Example:

```matlab
clear; clc;

addpath('C:\Program Files\COMSOL\COMSOL63\Multiphysics\mli');

mphstart(2036);

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(true);

mphtags
```

To disconnect MATLAB from the COMSOL server:

```matlab
ModelUtil.disconnect;
```

## 7. Common Setup Problems

### Problem 1: MATLAB cannot find `mphload` or `mphstart`

Likely cause:

```text
The COMSOL LiveLink mli folder is not on the MATLAB path.
```

Fix:

```matlab
addpath('<COMSOL_ROOT>\mli')
```

Example:

```matlab
addpath('C:\Program Files\COMSOL\COMSOL63\Multiphysics\mli')
```

### Problem 2: COMSOL starts the wrong MATLAB version

Likely cause:

```text
The MATLAB root directory stored in COMSOL preferences points to an old MATLAB installation.
```

Fix in COMSOL Desktop:

```text
File → Preferences → LiveLink Connections → LiveLink for MATLAB
```

Update the MATLAB installation folder.

On Windows, click:

```text
Register MATLAB as COM Server
```

Then restart COMSOL.

### Problem 3: Connection fails because the port is wrong

Likely cause:

```text
The COMSOL server is not listening on the assumed port.
```

Fix:

- Check the port number displayed in the COMSOL server window.
- Use that port in MATLAB.

Example:

```matlab
mphstart(2037)
```

### Problem 4: Username/password is requested unexpectedly

Possible causes:

- first-time setup on this machine,
- user preference file was reset,
- manual connection to another COMSOL server,
- login information is not available to the client machine.

Fix:

- Enter the local COMSOL server username/password.
- Do not use sensitive personal passwords.
- If necessary, reset the saved login information using `-login force`.

### Problem 5: Remote server connection fails

Check:

- server IP address or hostname,
- port number,
- username/password,
- firewall settings,
- whether the correct COMSOL server is running,
- whether the license supports this workflow.

## 8. Lab Policy

Do not commit any of the following to GitHub:

- real COMSOL server passwords,
- personal usernames,
- machine-specific absolute paths unless clearly marked as examples,
- license server information,
- private server IP addresses.

Use placeholders instead:

```text
<COMSOL_ROOT>
<MATLAB_ROOT>
<SERVER_HOSTNAME>
<PORT>
<USERNAME>
<PASSWORD>
```

## 9. Minimal Connection Test

After setup, run:

```matlab
clear; clc;

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(true);

disp('COMSOL LiveLink connection appears to be active.');
mphtags
```

If `mphtags` runs without error, MATLAB is connected to a COMSOL server.

## 10. Recommended Next Step

After the environment setup is verified, continue with the basic single-run
workflow and then the single-geometry validation case:

```text
docs/matlab_livelink_basic_workflow.md
templates/livelink_minimal_workflow.m
cases/case_001_validation_before_sweep.md
```

The environment setup and single-geometry validation should both be completed
before running large parameter sweeps or automated post-processing scripts.

