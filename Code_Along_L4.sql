-- 1. Skapa en ny databas
USE master;
GO

CREATE DATABASE DevSecOpsPerfSandbox;
GO

USE DevSecOpsPerfSandbox;
GO

-- DROP TABLE Users_Heap
-- DROP TABLE Users_Clustered

-- 2. Skapa en tabell utan PK och index (Detta blir alltså en Heap)
CREATE TABLE Users_Heap
(
	Id INT NOT NULL,
	Username VARCHAR(50) NOT NULL,
	Email VARCHAR(100) NOT NULL,
	CreatedAt DATETIME2 DEFAULT GETDATE()
);

-- 3. Skapa en identisk tabell som ska ha ett klustrat index
CREATE TABLE Users_Clustered
(
	Id INT NOT NULL,
	Username VARCHAR(50) NOT NULL,
	Email VARCHAR(100) NOT NULL,
	CreatedAt DATETIME2 DEFAULT GETDATE()
);

-- Skapa det klustrade indexet manuellt (efterliknar en Primary Key)
CREATE CLUSTERED INDEX CX_Users_Clustered_Id
ON Users_Clustered(Id);

-- 4. Mata in 50 000 rader i båda tabellerna med en loop
SET NOCOUNT ON;
DECLARE @i INT = 1;
WHILE @i <= 50000
BEGIN
	INSERT INTO Users_Heap(Id, Username, Email)
	VALUES (@i, 'User_' + CAST(@i AS VARCHAR(10)), 'User_' + CAST(@i AS VARCHAR(10)) + '@devsecops.se');

	INSERT INTO Users_Clustered(Id, Username, Email)
	VALUES (@i, 'User_' + CAST(@i AS VARCHAR(10)), 'User_' + CAST(@i AS VARCHAR(10)) + '@devsecops.se');
	SET @i = @i + 1;
END;
GO

PRINT 'Inmatning klar';
SET NOCOUNT OFF;

-- Aktivera I/O statistik för att se resursförbrukningen i meddelandefliken
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- TEST 1: Sökning i Heap - resulterar i en Table Scan
PRINT '--- Sökning i Heap---';
SELECT Id, Username, Email
FROM Users_Heap
WHERE Id = 42500;

-- TEST 2: Sökning i Clustered Index - resulterar i Clustered Index Seek
PRINT '--- Sökning i Clustered Index---';
SELECT Id, Username, Email
FROM Users_Clustered
WHERE Id = 42500;

-- Titta i fliken "Messages" i SSMS efter körning och jämför de två testerna, specifikt Logical Reads.

-- *************************************************************************************************** --

-- Framkalla och analysera en Key Lookup och skapa ett icke-klustrat index på enbart Username
CREATE NONCLUSTERED INDEX IX_Users_Clustered_Username
ON Users_Clustered(Username);
GO

-- Kör frågan med faktiskt exekveringspan aktiverad (Ctrl + M i SSMS)
SELECT Username, Email
FROM Users_Clustered
WHERE Username = 'User_35000';