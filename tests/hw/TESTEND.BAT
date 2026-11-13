@ECHO OFF
ECHO ok: 26 the chain to TESTEND worked
ECHO ===== the result: each file below is one failed check (Fnn = check nn)
DIR \FAILS
ECHO (0 file(s) above: all 74 checks passed)
ECHO ----- last: GOTO a missing label (its error message is right)
GOTO nosuchlabel
ECHO FAIL: 27 the missing label did not stop the batch file
TOUCH \FAILS\F27.TXT
