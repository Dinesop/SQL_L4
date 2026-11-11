-- =========================================================================
-- FAILSAFE IT - TOTALT FACIT-SKRIPT: LEKTION 3
-- Innehåller: Block 1 (Steg-för-steg Legacy-städning + Verifierings-JOIN) & Block 2-4 (Greenfield M:M)
-- Namnstandard: PK heter alltid Id. FK heter <Tabellnamn>Id.
-- =========================================================================

-- =========================================================================
-- INITIALISERING (Rensar och förbereder databasen för lektionen)
-- =========================================================================
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'FailSafe_Lektion3')
    DROP DATABASE FailSafe_Lektion3;
GO

CREATE DATABASE FailSafe_Lektion3;
GO

USE FailSafe_Lektion3;
GO

-- =========================================================================
-- BLOCK 1: CASE A - STEG-FÖR-STEG NORMALISERING AV LEGACY KAOS-DATA
-- =========================================================================

-- --- STEG 0: DET O-NORMALISERADE TILLSTÅNDET (UNF) ---
CREATE TABLE Legacy_Incident_Chaos (
    ServerName NVARCHAR(100),
    Incident_And_Date NVARCHAR(250),  
    InvestigatedByTechs NVARCHAR(MAX) 
);

INSERT INTO Legacy_Incident_Chaos VALUES 
('Prod-Web-01', 'DDoS:2026-11-05', 'Erik Nilsson, Lina Berg'),
('Prod-Web-01', 'SQLi-Attempt:2026-11-06', 'Lina Berg'),
('Dev-Db-01', 'UnauthorizedAccess:2026-11-07', 'Erik Nilsson, Anna Stark'),
('Test-App-04', 'None:2026-11-08', 'Kalle Blomqvist');
GO


-- --- STEG 1: FÖRSTA NORMALFORMEN (1NF) ---
CREATE TABLE Incident_1NF (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(100),
    IncidentType NVARCHAR(100),
    IncidentDate DATE,
    TechName NVARCHAR(150)
);

INSERT INTO Incident_1NF (ServerName, IncidentType, IncidentDate, TechName) VALUES 
('Prod-Web-01', 'DDoS', '2026-11-05', 'Erik Nilsson'),
('Prod-Web-01', 'DDoS', '2026-11-05', 'Lina Berg'),
('Prod-Web-01', 'SQLi-Attempt', '2026-11-06', 'Lina Berg'),
('Dev-Db-01', 'UnauthorizedAccess', '2026-11-07', 'Erik Nilsson'),
('Dev-Db-01', 'UnauthorizedAccess', '2026-11-07', 'Anna Stark'),
('Test-App-04', 'None', '2026-11-08', 'Kalle Blomqvist');
GO


-- --- STEG 2: ANDRA NORMALFORMEN (2NF) ---
CREATE TABLE IncidentServers_2NF (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(100)
);

CREATE TABLE Incidents_And_Techs_2NF (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IncidentServersId INT, 
    IncidentType NVARCHAR(100),
    IncidentDate DATE,
    TechName NVARCHAR(150)
);

INSERT INTO IncidentServers_2NF (ServerName)
SELECT DISTINCT ServerName FROM Incident_1NF;

INSERT INTO Incidents_And_Techs_2NF (IncidentServersId, IncidentType, IncidentDate, TechName) VALUES 
(1, 'DDoS', '2026-11-05', 'Erik Nilsson'),
(1, 'DDoS', '2026-11-05', 'Lina Berg'),
(1, 'SQLi-Attempt', '2026-11-06', 'Lina Berg'),
(2, 'UnauthorizedAccess', '2026-11-07', 'Erik Nilsson'),
(2, 'UnauthorizedAccess', '2026-11-07', 'Anna Stark'),
(3, 'None', '2026-11-08', 'Kalle Blomqvist');
GO


-- --- STEG 3: TREDJE NORMALFORMEN (3NF & UPPLÖST M:M) ---
CREATE TABLE IncidentServers (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE SecurityTechs (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    TechName NVARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE Incidents (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IncidentServersId INT FOREIGN KEY REFERENCES IncidentServers(Id),
    IncidentType NVARCHAR(100) NOT NULL,
    IncidentDate DATE NOT NULL
);

CREATE TABLE IncidentAssignments (
    IncidentsId INT NOT NULL,
    SecurityTechsId INT NOT NULL,
    CONSTRAINT PK_IncidentAssignments PRIMARY KEY (IncidentsId, SecurityTechsId),
    CONSTRAINT FK_Assignment_Incidents FOREIGN KEY (IncidentsId) REFERENCES Incidents(Id),
    CONSTRAINT FK_Assignment_SecurityTechs FOREIGN KEY (SecurityTechsId) REFERENCES SecurityTechs(Id)
);
GO

-- Populera de skarpa 3NF-tabellerna
INSERT INTO IncidentServers (ServerName) 
SELECT ServerName FROM IncidentServers_2NF;

INSERT INTO SecurityTechs (TechName) VALUES 
('Erik Nilsson'), ('Lina Berg'), ('Anna Stark'), ('Kalle Blomqvist');

INSERT INTO Incidents (IncidentServersId, IncidentType, IncidentDate) VALUES 
(1, 'DDoS', '2026-11-05'),
(1, 'SQLi-Attempt', '2026-11-06'),
(2, 'UnauthorizedAccess', '2026-11-07'),
(3, 'None', '2026-11-08');

INSERT INTO IncidentAssignments (IncidentsId, SecurityTechsId) VALUES 
(1, 1), (1, 2), (2, 2), (3, 1), (3, 3), (4, 4);
GO

-- --- VERIFIERING: ÅTERSKAPA URSKUNGLIG KAOSDATA VIA JOINS ---
SELECT 
    s.ServerName,
    i.IncidentType + ':' + CONVERT(VARCHAR, i.IncidentDate, 23) AS Incident_And_Date,
    t.TechName AS InvestigatedByTech
FROM Incidents i
INNER JOIN IncidentServers s ON i.IncidentServersId = s.Id
INNER JOIN IncidentAssignments a ON i.Id = a.IncidentsId
INNER JOIN SecurityTechs t ON a.SecurityTechsId = t.Id;
GO


-- =========================================================================
-- BLOCK 2: CASE B - HÄRDAD GREENFIELD M:M DDL (Från User Stories)
-- =========================================================================
CREATE TABLE BackupServers (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE BackupPolicies (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    PolicyName NVARCHAR(100) NOT NULL UNIQUE,
    IntervalHours INT NOT NULL
);

CREATE TABLE ServerPolicyMaps (
    BackupServersId INT NOT NULL,
    BackupPoliciesId INT NOT NULL,
    IsActive BIT DEFAULT 1,
    CONSTRAINT PK_ServerPolicyMaps PRIMARY KEY (BackupServersId, BackupPoliciesId),
    CONSTRAINT FK_Map_BackupServers FOREIGN KEY (BackupServersId) REFERENCES BackupServers(Id),
    CONSTRAINT FK_Map_BackupPolicies FOREIGN KEY (BackupPoliciesId) REFERENCES BackupPolicies(Id)
);

CREATE TABLE BackupAuditTrail (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    BackupServersId INT NOT NULL,
    BackupPoliciesId INT NOT NULL,
    ActionExecuted NVARCHAR(100) NOT NULL,
    ExecutedByUser NVARCHAR(100) DEFAULT SYSTEM_USER,
    LogTimestamp DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Audit_ServerPolicyMaps FOREIGN KEY (BackupServersId, BackupPoliciesId) REFERENCES ServerPolicyMaps(BackupServersId, BackupPoliciesId)
);
GO


-- =========================================================================
-- BLOCK 3: SEED-DATA & DML FRÅN MOCKAROO (Slank testdata för pipelines)
-- =========================================================================
INSERT INTO BackupServers (ServerName) VALUES 
('Prod-Web-01'), 
('Dev-Db-01'), 
('Stage-App-02');

INSERT INTO BackupPolicies (PolicyName, IntervalHours) VALUES 
('Daily-Incremental', 24), 
('Weekly-Full', 168);

INSERT INTO ServerPolicyMaps (BackupServersId, BackupPoliciesId) VALUES 
(1, 1),
(1, 2),
(2, 1),
(3, 2);

INSERT INTO BackupAuditTrail (BackupServersId, BackupPoliciesId, ActionExecuted) VALUES 
(1, 1, 'POLICY_ATTACHED_SUCCESS');
GO


-- =========================================================================
-- BLOCK 4: AUTOMATISERAD VERIFIERINGSLOGG (Pipeline-kontroll)
-- =========================================================================
SELECT 'Legacy Incident Servers' AS [Table Name], COUNT(*) AS [Number of records] FROM IncidentServers
UNION ALL
SELECT 'Legacy Security Techs', COUNT(*) FROM SecurityTechs
UNION ALL
SELECT 'Legacy Total Incidents', COUNT(*) FROM Incidents
UNION ALL
SELECT 'Greenfield Backup Servers', COUNT(*) FROM BackupServers
UNION ALL
SELECT 'Greenfield Backup Policies', COUNT(*) FROM BackupPolicies
UNION ALL
SELECT 'Greenfield M:M Policy Maps', COUNT(*) FROM ServerPolicyMaps
UNION ALL
SELECT 'Greenfield Audit Trail Logs', COUNT(*) FROM BackupAuditTrail;
GO