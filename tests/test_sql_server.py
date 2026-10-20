"""Run the actual portfolio SQL against an isolated SQL Server fixture database.

Requires sqlcmd and a local SQL Server with Windows authentication. The unique
CodexPortfolioTest_* database is removed in finally; existing databases are unused.
"""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]

def sql(server, text):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', encoding='utf-8', delete=False) as f:
        f.write(text)
        path = Path(f.name)
    try:
        result = subprocess.run(['sqlcmd', '-S', server, '-E', '-C', '-b', '-r', '1', '-l', '10', '-W', '-h', '-1', '-s', '|', '-i', str(path)], capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout[-2500:] + result.stderr[-2500:])
        return result.stdout
    finally:
        path.unlink(missing_ok=True)

def script(name, database):
    return (ROOT / name).read_text(encoding='utf-8-sig').replace('[Portfolio Project]', f'[{database}]')

FIXTURE = """
CREATE TABLE dbo.NashvilleHousing (
 [UniqueID ] int, ParcelID nvarchar(50), PropertyAddress nvarchar(255),
 SaleDate datetime, SalePrice int, LegalReference nvarchar(50),
 OwnerAddress nvarchar(255), TaxDistrict nvarchar(50), SoldAsVacant nvarchar(10)
);
INSERT INTO dbo.NashvilleHousing VALUES
 (1,'P1','123 Main St, Nashville','2020-01-02T12:30:00',100,'L1','45 St. John Rd, Nashville, TN','T','Y'),
 (2,'P1',NULL,'2020-01-03',110,'L2',NULL,'T','N'),
 (3,'P2','No comma address','2020-01-04',120,'L3','No comma owner','T','Yes'),
 (4,'P3','First Address, Nashville','2020-01-05',130,'L4','A, Nashville, TN','T','N'),
 (5,'P3','Other Address, Nashville','2020-01-06',140,'L5','B, Nashville, TN','T','Y'),
 (6,'P3',NULL,'2020-01-07',150,'L6',NULL,'T','N');
CREATE TABLE dbo.CovidDeaths$ (
 continent nvarchar(50), location nvarchar(100), date date, population bigint,
 total_cases bigint, new_cases bigint, total_deaths nvarchar(50), new_deaths nvarchar(50)
);
INSERT INTO dbo.CovidDeaths$ VALUES
 ('Europe','Country A','2020-01-01',1000,100,100,'5','5'),
 ('Europe','Country A','2020-01-02',1000,200,100,'10','5'),
 ('Europe','Country B','2020-01-01',1000,50,50,'3','3'),
 ('Europe','Country B','2020-01-02',1000,100,50,'7','4'),
 ('North America','United States','2020-01-01',1000,0,0,'0','0'),
 ('North America','United States','2020-01-02',1000,100,100,'1','1'),
 ('Test','Zero','2020-01-01',0,0,0,'0','0'),
 (NULL,'World','2020-01-01',3000,150,150,'8','8');
CREATE TABLE dbo.CovidVaccinations$ (location nvarchar(100), date date, new_vaccinations bigint);
INSERT INTO dbo.CovidVaccinations$ VALUES
 ('Country A','2020-01-01',100), ('Country A','2020-01-02',150),
 ('Country B','2020-01-01',10), ('Country B','2020-01-02',20),
 ('United States','2020-01-01',0), ('United States','2020-01-02',5),
 ('Zero','2020-01-01',0), ('World','2020-01-01',110);
GO
"""

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--server', default='localhost')
    args = parser.parse_args()
    db = 'CodexPortfolioTest_' + uuid.uuid4().hex
    # Only a new, uniquely named test database is ever created or dropped.
    assert re.fullmatch(r'CodexPortfolioTest_[0-9a-f]{32}', db)
    sql(args.server, f'CREATE DATABASE [{db}];')
    try:
        sql(args.server, f'USE [{db}];\nGO\n' + FIXTURE)
        housing = script('Nashville Housing Data Cleaning Scripts.sql', db)
        sql(args.server, f'USE [{db}];\nGO\n' + housing)
        sql(args.server, f'USE [{db}];\nGO\n' + housing)
        sql(args.server, f"""USE [{db}];
IF (SELECT COUNT(*) FROM dbo.NashvilleHousing) <> 6 THROW 51000,'Rows were lost',1;
IF NOT EXISTS (SELECT 1 FROM dbo.NashvilleHousing WHERE [UniqueID ]=1 AND SaleDateConverted='2020-01-02' AND DATEPART(hour,SaleDate)=12 AND OwnerSplitAddress='45 St. John Rd' AND OwnerSplitCity='Nashville' AND OwnerSplitState='TN') THROW 51000,'Date or owner address changed incorrectly',1;
IF NOT EXISTS (SELECT 1 FROM dbo.NashvilleHousing WHERE [UniqueID ]=2 AND PropertyAddress='123 Main St, Nashville' AND SoldAsVacant='NO') THROW 51000,'Address fill or flag failed',1;
IF NOT EXISTS (SELECT 1 FROM dbo.NashvilleHousing WHERE [UniqueID ]=3 AND PropertySplitAddress='No comma address' AND PropertySplitCity IS NULL) THROW 51000,'Missing comma handling failed',1;
IF NOT EXISTS (SELECT 1 FROM dbo.NashvilleHousing WHERE [UniqueID ]=6 AND PropertyAddress IS NULL) THROW 51000,'Ambiguous parcel address was guessed',1;
""")
        print('PASS Nashville: clean run, rerun, missing commas, periods, ambiguous parcel, original data retained')
        covid = script('Covid Portfolio Project Scripts.sql', db)
        sql(args.server, f'USE [{db}];\nGO\n' + covid)
        sql(args.server, f'USE [{db}];\nGO\n' + covid)
        # Execute the real continent query on a fixture with repeated cumulative
        # totals; a continent MAX or sum across all dates both yield wrong totals.
        continent = covid.split('-- Continents by total death count', 1)[1].split('-- GLOBAL NUMBERS',1)[0].strip().rstrip(';')
        result = sql(args.server, f'USE [{db}]; SET NOCOUNT ON;\n' + continent)
        assert 'Europe|17' in result.splitlines(), result
        sql(args.server, f"""USE [{db}];
IF NOT EXISTS (SELECT 1 FROM dbo.PercentPopulationVaccinated WHERE location='Country A' AND date='2020-01-02' AND RollingVaccinationDoses=250) THROW 51000,'Rolling dose calculation failed',1;
IF EXISTS (SELECT 1 FROM dbo.PercentPopulationVaccinated WHERE continent IS NULL) THROW 51000,'Aggregate locations leaked into view',1;
""")
        print('PASS COVID: clean run, rerun, zero denominators, continent total, cumulative doses, country filtering')
    finally:
        sql(args.server, f'USE master; ALTER DATABASE [{db}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{db}];')

if __name__ == '__main__':
    main()
