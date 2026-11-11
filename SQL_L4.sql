-- Uppgift 1: Skapa en hög (Heap)
CREATE TABLE AuditLogs_Heap
(
	Id INT NOT NULL,
	LogMessage NVARCHAR(500) NOT NULL, 
	CreatedAt DATETIME2 NOT NULL
);
GO

-- Uppgift 2: Det automatiska indexet (Clustrered)
CREATE TABLE AuditLogs_Clustered
(
	Id INT NOT NULL,
	LogMessage NVARCHAR(500) NOT NULL, 
	CreatedAt DATETIME2 NOT NULL
	CONSTRAINT PK_AuditLogs_Clustered PRIMARY KEY CLUSTERED (Id)
);
GO

-- Uppgift 3: Det kirurgiska snittet (Non-Clustered)
CREATE NONCLUSTERED INDEX IX_AuditLogs_CreatedAt
ON AuditLogs_Clustered(CreatedAt)
GO

-- Populera tabellen
SET NOCOUNT ON;
DECLARE @Counter INT = 1;
DECLARE @RandomMessage NVARCHAR(500);
DECLARE @RandomDate DATETIME2;

WHILE @Counter <=50000
BEGIN
	SET @RandomMessage = N'DevSecOps Audit event log #' 
		+ CAST(@Counter AS NVARCHAR(10))
		+ N' - Firewall traffic authorized.';
	SET @RandomDate = DATEADD(SECOND, @Counter, '2026-01-01 00:00:00'); --Sprider ut tids

	-- Skjut into Heap
	INSERT INTO AuditLogs_Heap(Id, LogMessage, CreatedAt)
	VALUES (@Counter, @RandomMessage, @RandomDate);

	-- Skjut into Clustered
	INSERT INTO AuditLogs_Clustered(Id, LogMessage, CreatedAt)
	VALUES (@Counter, @RandomMessage, @RandomDate);

	SET @Counter = @Counter + 1;
END
-- Återställ systeminställning och verifiera dataladdningen 
SET NOCOUNT OFF;
PRINT 'Dataladdning klar. Verifierar radantal:';

SELECT 'AuditLogs_Heap Count' AS TableName, COUNT (*) AS 'Number of rows' FROM AuditLogs_Heap
UNION ALL -- Uniferar selectarna
SELECT 'AuditLogs_Clustered Count' AS TableName, COUNT (*) FROM AuditLogs_Clustered;
GO

-- Uppgift 4: Verifiera indexstrukturen
-- SELECT TOP 10 * FROM sys.indexes

SELECT name, type_desc FROM sys.indexes 
WHERE object_id =  object_id('dbo.AuditLogs_Clustered');

-- Uppgift 5: Säkerställa unika värden. 
-- INSERT INTO Servers(ServerName)
-- VALUES ('Dev-Db-01', 'Prod-Web-01', 'Test-App-04');

-- ALTER TABLE dbo.Servers
-- ADD CONSTRAINT UQ_Servers_ServerName UNIQUE (ServerName);

-- Uppgift 6: Detektera en Table Scan
SELECT * FROM AuditLogs_Heap
WHERE LogMessage = 'DevSecOps Audit event log #45345 - Firewall traffic authorized.';
-- SQL Server visar att den har gjort en Table Scan och letat igenom alla 50 000 rader

-- Uppgift 7: Blixtsnabb sökning (Index Seek)
SELECT * FROM AuditLogs_Clustered
WHERE Id = 45345;

-- Uppgift 8: Den dolda kostnaden (Key Lookup)
SELECT LogMessage FROM AuditLogs_Clustered WHERE CreatedAt = GETDATE();

-- Uppgift 9: Den perfekta skölden (Covering Index)
-- Bygg om indexet med INCLUDE för att lägga till texten som payload i leaf nodes
DROP INDEX IX_AuditLogs_CreatedAt ON AuditLogs_Clustered;
GO

CREATE NONCLUSTERED INDEX IX_AuditLogs_CreatedAt
ON AuditLogs_Clustered(CreatedAt)
INCLUDE (Logmessage)
GO

SELECT LogMessage FROM AuditLogs_Clustered WHERE CreatedAt = GETDATE();

-- Uppgift 10: SARGable kodtvätt
-- istället för incidents så använder vi vår clustered tabell och createdAt kolumnen

-- Dålig fråga:
SELECT * FROM AuditLogs_Clustered
WHERE YEAR(CreatedAt) = 2026;

-- Bra (SARGable) fråga:
-- här stoppar vi inte in vår CreatedAt i en funktion och vi får en Index Seek istället för en Index Scan
SELECT * FROM AuditLogs_Clustered
WHERE CreatedAt >= '2026-01-01 00:00:00' AND CreatedAt <= '2027-01-01 00:00:00';

-- Kör frågorna många gånger för att tydligare visa hastighetsskillnaden
-- Sätt tidsmätning och räknare i minnet

SET NOCOUNT ON;

DECLARE @Counter INT = 1;
DECLARE @MaxCounter INT = 10;
DECLARE @StartTid DATETIME;
DECLARE @SlutTid DATETIME;

SET @StartTid = GETDATE();
WHILE @Counter <= @MaxCounter
BEGIN
	-- Dålig fråga:
	SELECT * FROM AuditLogs_Clustered
	WHERE YEAR(CreatedAt) = 2026;
	
	SET @Counter = @Counter + 1;

END;
SET @SlutTid = GETDATE();
PRINT 'Exekveringstid för dålig fråga: ' + CONVERT(VARCHAR, @SlutTid - @StartTid, 114)

DECLARE @Counter INT = 1;
DECLARE @MaxCounter INT = 10;
DECLARE @StartTid DATETIME;
DECLARE @SlutTid DATETIME;

SET @StartTid = GETDATE();
WHILE @Counter <= @MaxCounter
BEGIN
	-- Dålig fråga:
	SELECT * FROM AuditLogs_Clustered
	WHERE YEAR(CreatedAt) = 2026;
	
	SET @Counter = @Counter + 1;

END;
SET @SlutTid = GETDATE();
PRINT 'Exekveringstid för dålig fråga: ' + CONVERT(VARCHAR, @SlutTid - @StartTid, 114)

-- Återställ systeminställning och verifiera dataladdningen 
SET NOCOUNT OFF;
PRINT 'Klar.';

-- Uppgift 11: Indexera länkade nycklar (FK Optimering) 
-- Fel i övningsuppgifter så vi byter dbo.
USE FailSafe_Lektion3
GO

CREATE NONCLUSTERED INDEX IX_IncidentsServersId
ON dbo.Incidents(IncidentsServersId);
GO

-- Uppgift 12: Contradiction Detection i praktiken
ALTER TABLE dbo.ServerPolicyMaps
ADD CONSTRAINT CHK_ServerPolicyMaps_IsActive 
	CHECK (IsActive IN (0,1));
GO

SELECT * FROM dbo.ServerPolicyMap
WHERE IsActive = 5;