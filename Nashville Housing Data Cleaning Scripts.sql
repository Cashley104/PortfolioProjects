/* SQL Server housing-cleaning walkthrough.
   Run against an imported dbo.NashvilleHousing table in [Portfolio Project].
   Original columns are retained for audit/review; duplicate rows are flagged,
   not deleted. Rerunning the script does not add duplicate columns.
*/
USE [Portfolio Project];
GO

-- Standardize dates without overwriting the source timestamp.
IF COL_LENGTH('dbo.NashvilleHousing', 'SaleDateConverted') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD SaleDateConverted date;
GO
UPDATE dbo.NashvilleHousing
SET SaleDateConverted = TRY_CONVERT(date, SaleDate);

-- Populate missing property addresses only when the parcel has one distinct
-- nonblank known address. Conflicting parcel addresses stay unresolved.
;WITH ParcelAddress AS (
    SELECT ParcelID, MIN(LTRIM(RTRIM(PropertyAddress))) AS PropertyAddress
    FROM dbo.NashvilleHousing
    WHERE NULLIF(LTRIM(RTRIM(PropertyAddress)), '') IS NOT NULL
    GROUP BY ParcelID
    HAVING COUNT(DISTINCT LTRIM(RTRIM(PropertyAddress))) = 1
)
UPDATE a
SET PropertyAddress = b.PropertyAddress
FROM dbo.NashvilleHousing AS a
INNER JOIN ParcelAddress AS b ON a.ParcelID = b.ParcelID
WHERE NULLIF(LTRIM(RTRIM(a.PropertyAddress)), '') IS NULL;
GO

-- Split property address. A missing comma means city is unknown.
IF COL_LENGTH('dbo.NashvilleHousing', 'PropertySplitAddress') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD PropertySplitAddress nvarchar(255);
IF COL_LENGTH('dbo.NashvilleHousing', 'PropertySplitCity') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD PropertySplitCity nvarchar(255);
GO
UPDATE dbo.NashvilleHousing
SET PropertySplitAddress = LTRIM(RTRIM(CASE WHEN CHARINDEX(',', PropertyAddress) > 0
        THEN LEFT(PropertyAddress, CHARINDEX(',', PropertyAddress) - 1)
        ELSE PropertyAddress END)),
    PropertySplitCity = CASE WHEN CHARINDEX(',', PropertyAddress) > 0
        THEN NULLIF(LTRIM(RTRIM(SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, 255))), '')
        ELSE NULL END;
GO

-- Split owner address from its last two commas, preserving periods in streets.
IF COL_LENGTH('dbo.NashvilleHousing', 'OwnerSplitAddress') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD OwnerSplitAddress nvarchar(255);
IF COL_LENGTH('dbo.NashvilleHousing', 'OwnerSplitCity') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD OwnerSplitCity nvarchar(255);
IF COL_LENGTH('dbo.NashvilleHousing', 'OwnerSplitState') IS NULL
    ALTER TABLE dbo.NashvilleHousing ADD OwnerSplitState nvarchar(255);
GO
;WITH OwnerParts AS (
    SELECT *, CHARINDEX(',', REVERSE(OwnerAddress)) AS LastCommaFromEnd
    FROM dbo.NashvilleHousing
), OwnerDelimiters AS (
    SELECT *, CASE WHEN LastCommaFromEnd > 0
        THEN CHARINDEX(',', REVERSE(OwnerAddress), LastCommaFromEnd + 1)
        ELSE 0 END AS SecondCommaFromEnd
    FROM OwnerParts
)
UPDATE OwnerDelimiters
SET OwnerSplitAddress = CASE WHEN SecondCommaFromEnd > 0
        THEN NULLIF(LTRIM(RTRIM(LEFT(OwnerAddress, LEN(OwnerAddress) - SecondCommaFromEnd))), '')
        ELSE OwnerAddress END,
    OwnerSplitCity = CASE WHEN SecondCommaFromEnd > 0
        THEN NULLIF(LTRIM(RTRIM(SUBSTRING(OwnerAddress,
            LEN(OwnerAddress) - SecondCommaFromEnd + 2,
            SecondCommaFromEnd - LastCommaFromEnd - 1))), '')
        ELSE NULL END,
    OwnerSplitState = CASE WHEN SecondCommaFromEnd > 0
        THEN NULLIF(LTRIM(RTRIM(RIGHT(OwnerAddress, LastCommaFromEnd - 1))), '')
        ELSE NULL END;
GO

-- Standardize Y/N while retaining other source values.
UPDATE dbo.NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
                       WHEN SoldAsVacant = 'N' THEN 'NO'
                       ELSE SoldAsVacant END;

-- Flag possible duplicates for review; no records are deleted.
;WITH RowNumCTE AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDateConverted, LegalReference
        ORDER BY [UniqueID ]
    ) AS row_num
    FROM dbo.NashvilleHousing
)
SELECT * FROM RowNumCTE WHERE row_num > 1 ORDER BY PropertyAddress;

-- Review cleaned columns alongside original values.
SELECT * FROM dbo.NashvilleHousing;
