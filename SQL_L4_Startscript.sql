/* ============================================================================
   FAILSAFE IT - INFRASTRUKTUR- OCH BEHÖRIGHETSREGISTER
   STARTSKRIPT FÖR LEKTION 4: Driftoptimering, Indexering, 
            Exekveringsplaner och Constraints
   ============================================================================ */

USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'FailSafe_Lektion4')
BEGIN
    ALTER DATABASE FailSafe_Lektion4 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FailSafe_Lektion4;
END
GO

CREATE DATABASE FailSafe_Lektion4;
GO

USE FailSafe_Lektion4;
GO



PRINT 'FailSafeIT-databasen är skapad och preparerad för Lektion 4!';