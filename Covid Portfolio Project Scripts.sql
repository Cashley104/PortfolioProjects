USE [Portfolio Project];
GO

Select *
From [Portfolio Project]..CovidDeaths$
Where continent is not null
order by 3,4

--Select *
--From [Portfolio Project]..CovidVaccinations$
--order by 3,4

Select Location, date, total_cases, new_cases, total_deaths, Population
From [Portfolio Project]..CovidDeaths$
order by 1,2

-- Looking at Total Cases vs. Total Deaths

Select Location, date, total_cases, total_deaths, (TRY_CONVERT(float,total_deaths)/NULLIF(total_cases,0))*100 as DeathPercentage
From [Portfolio Project]..CovidDeaths$
Where location like '%states%'
order by 1,2


-- Looking at Total Cases vs. Population

Select Location, date, Population, total_cases, (CONVERT(float,total_cases)/NULLIF(population,0))*100 as AfflictedPercentage
From [Portfolio Project]..CovidDeaths$
--Where location like %states%
order by 1,2


-- Looking at Countries with Highest Infection Rate compared to Population

Select Location,Population, MAX(total_cases) as HighestInfectionCount, MAX(CONVERT(float,total_cases)/NULLIF(population,0))*100 as AfflictedPercentage
From [Portfolio Project]..CovidDeaths$
--Where location like %states%'
Group by location, population
order by AfflictedPercentage desc

-- Showing Countries with Highest Total Death Count

Select Location, MAX(TRY_CONVERT(bigint,total_deaths)) as TotalDeathCount
From [Portfolio Project]..CovidDeaths$
--Where location like %states%'
Where continent is not null
Group by location
order by TotalDeathCount desc

-- Continents by total death count

;WITH CountryDeaths AS (
    SELECT continent, location, MAX(TRY_CONVERT(bigint,total_deaths)) AS TotalDeathCount
    FROM [Portfolio Project]..CovidDeaths$
    WHERE continent IS NOT NULL
    GROUP BY continent, location
)
SELECT continent, SUM(TotalDeathCount) AS TotalDeathCount
FROM CountryDeaths
GROUP BY continent;


-- GLOBAL NUMBERS

Select SUM(CONVERT(bigint,new_cases)), SUM(TRY_CONVERT(bigint,new_deaths)) as total_deaths,  100.0*SUM(TRY_CONVERT(bigint,new_deaths))/NULLIF(SUM(CONVERT(bigint,new_cases)),0) as DeathPercentage
From [Portfolio Project]..CovidDeaths$
--Where location like %states%
where continent is not null
--Group by date
order by 1,2


-- Total Pop vs. Vaccinations


Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingVaccinationDoses

From [Portfolio Project]..CovidDeaths$ dea
join [Portfolio Project]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
order by 2,3



-- Vaccination counts are doses administered, not distinct vaccinated people.
-- USE CTE

;With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingVaccinationDoses)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinationDoses

From [Portfolio Project]..CovidDeaths$ dea
join [Portfolio Project]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
--order by 2,3
)
Select *, (100.0*RollingVaccinationDoses/NULLIF(Population,0)) as DosesPer100People
From PopvsVac

-- TEMP TABLE

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric(28,0),
New_vaccinations numeric(28,0),
RollingVaccinationDoses numeric(28,0)
)
Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinationDoses
From [Portfolio Project]..CovidDeaths$ dea
join [Portfolio Project]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
--where dea.continent is not null
--order by 2,3

Select *, (100.0*RollingVaccinationDoses/NULLIF(Population,0)) as DosesPer100People
From #PercentPopulationVaccinated


-- Creating View to store data for later visualizations

GO

-- Legacy view name retained for compatibility. Values measure doses, not people.
CREATE OR ALTER VIEW dbo.PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingVaccinationDoses
From [Portfolio Project]..CovidDeaths$ dea
join [Portfolio Project]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null
--order by 2,3

GO


Select *
From PercentPopulationVaccinated
