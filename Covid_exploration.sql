/*
Data exploration of Covid 19 dataset from Our World in Data:
https://github.com/owid/covid-19-data/tree/master/public/data

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views
Uses MySQL server

*/
use portfolioproject;

-- Now that we finally have the data loaded, let's do some exploration

SELECT *
FROM deaths;

SELECT *
FROM vaccinations;

-- Select the data that we're going to be using
SELECT location, record_date, total_cases, new_cases, new_cases_per_million, total_deaths, population
FROM deaths
ORDER BY 1, 2;

desc vaccinations;

-- Looks at total cases vs. total deaths and the percentage of death among all cases in a few different countries
SELECT location, record_date, total_cases, total_deaths, (total_deaths/total_cases)*100 death_percentage
FROM deaths
WHERE location = 'United States'
ORDER BY 1, 2
LIMIT 3000;

SELECT location, record_date, total_cases, total_deaths, (total_deaths/total_cases)*100 death_percentage
FROM deaths
WHERE location = 'Philippines'
ORDER BY 1, 2;

SELECT location, MAX(total_cases) total_cases_so_far, MAX(total_deaths) total_deaths_so_far
FROM deaths
WHERE location IN ('Philippines', 'United States')
GROUP BY location;
-- So in the US, the total cases as of May 5, 2024 is > 103 million and total deaths is 1.186 million.
-- Whereas in the Philippines, the total cases as of the same date is only > 4.173 million and total deaths is 66 thousand.
-- The recorded total deaths in the US is almost 18 times as much as in the Philippines.
-- Why is this?

-- Total cases vs. Population
-- Shows what percentage of the Population got Covid
SELECT location, record_date, population, total_cases, (total_cases/population)*100 covid_percentage
FROM deaths
WHERE location = 'United States'
ORDER BY 1, 2;
-- As of May 5, 2024, 30% of people in the US have gotten covid.

SELECT location, record_date, population, total_cases, (total_cases/population)*100 covid_percentage
FROM deaths
WHERE location = 'Philippines'
ORDER BY 1, 2;
-- As of May 5, 2024, 3.58% of the total population in the Philippines have gotten covid.

-- Show countries with highest infection rate compared to total population
SELECT location, population, MAX(total_cases) total_cases, MAX((total_cases/population))*100 covid_percentage
FROM deaths
WHERE continent != ''
GROUP BY location, population
ORDER BY covid_percentage desc;

-- Show countries with highest death count
SELECT continent, location, MAX(total_deaths) total_death_count
FROM deaths
WHERE continent != ''
GROUP BY continent, location
ORDER BY total_death_count desc;

-- LET'S BREAK THINGS DOWN BY CONTINENT

-- Total cases vs. total deaths by country and by continent
SELECT continent, location, MAX(total_cases) total_cases_so_far, MAX(total_deaths) total_deaths_so_far
FROM deaths
WHERE continent != ''
GROUP BY continent, location
ORDER BY continent, total_deaths_so_far desc, total_cases_so_far desc;

-- Create a temp table that we can use for the following queries
DROP TEMPORARY TABLE IF EXISTS death_totals_by_country;
CREATE TEMPORARY TABLE death_totals_by_country
	(continent varchar(20),
	 location varchar(40),
     total_cases int unsigned,
     total_deaths int unsigned
	);
    
INSERT INTO death_totals_by_country
SELECT continent, location, MAX(total_cases) total_cases, MAX(total_deaths) total_deaths
FROM deaths
WHERE continent != ''
GROUP BY continent, location;

-- Show the highest total cases for each continent
SELECT continent, max(total_cases) highest_total_cases
FROM death_totals_by_country
GROUP BY continent
ORDER BY max(total_cases) desc;
/* TODO: Show the name of the actual country that this value corresponds to. */

-- Show the highest total deaths for each continent
SELECT continent, max(total_deaths) highest_total_deaths
FROM death_totals_by_country
GROUP BY continent
ORDER BY max(total_cases) desc;

-- Show continents' total death counts, ordered from highest to lowest
SELECT cont_deaths.continent, SUM(cont_deaths.total_deaths) total_death_count
FROM 
	(SELECT continent, location, MAX(total_deaths) total_deaths
	 FROM deaths
	 WHERE continent != ''
	 GROUP BY continent, location
    ) cont_deaths
WHERE continent != ''
GROUP BY continent
ORDER BY 2 desc;

-- GLOBAL NUMBERS

-- Show total cases and deaths worldwide
SELECT sum(new_cases) total_cases, sum(new_deaths) total_deaths
FROM deaths
WHERE continent != '';
-- Almost 775.5 million cases and greater than 7 million deaths worldwide as of May 5, 2024

-- Show new cases and deaths by date (reported weekly it seems)
SELECT record_date, sum(new_cases) new_cases_worldwide, sum(new_deaths) new_deaths_worldwide
FROM deaths
WHERE continent != ''
GROUP BY record_date
ORDER BY 1;

SELECT DISTINCT location
FROM deaths
WHERE continent != '';

-- Look at total population vs. vaccinations by location and date
SELECT d.continent, d.location, d.record_date, d.population, v.new_vaccinations,
	sum(v.new_vaccinations) OVER (partition by d.location ORDER BY d.location, d.record_date) rolling_vaccinations
    /* (rolling_vaccinations/d.population)*100 */
FROM deaths d
	INNER JOIN vaccinations v
    ON d.location = v.location
    AND d.record_date = v.record_date
WHERE d.continent != ''
ORDER BY 2, 3;

-- Look at the total people vaccinated divided by total population, by location and date
-- i.e., the above, but with the commented portion included, using CTE
WITH vac_pop AS
	(SELECT d.continent, d.location, d.record_date, d.population, v.new_vaccinations,
     sum(v.new_vaccinations) OVER (partition by d.location ORDER BY d.location, d.record_date) rolling_vaccinations
     FROM deaths d
		INNER JOIN vaccinations v
		ON d.location = v.location
        AND d.record_date = v.record_date
	 WHERE d.continent != ''
	)
SELECT vp.continent, vp.location, vp.record_date, vp.population, vp.new_vaccinations,
	vp.rolling_vaccinations, (vp.rolling_vaccinations/vp.population)*100 vaccination_percentage
FROM vac_pop vp;

-- Creating a view for later visualizations
CREATE VIEW vaccinations_population AS
SELECT d.continent, d.location, d.record_date, d.population, v.new_vaccinations,
	sum(v.new_vaccinations) OVER (partition by d.location ORDER BY d.location, d.record_date) rolling_vaccinations
FROM deaths d
	INNER JOIN vaccinations v
	ON d.location = v.location
	AND d.record_date = v.record_date
WHERE d.continent != '';

SELECT * FROM vaccinations_population;
