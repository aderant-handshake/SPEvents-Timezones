# Handshake, SharePoint Events and Datetime Fields

> Does anyone really know what time it is? 
> 
> -- Chicago, October 1970

## Introduction
This guide will discuss and review information related to how the Handshake Toolkit (3.8 and better) and Kendo UI Controls work with querying and displaying the correct date and time from a SharePoint Event item. From the event being replicated by ListGuru/Mirror, relative to the users timezone established by their SharePoint user settings, to the item's presentation based on the user's current time zone. 

While this information is pertinent and important if you operate in a single time zone, it is **critical** if you operate in multiple time zones. Topics include

- [Introduction](#introduction)
- [Included files](#included-files)
  - [sample.js](#samplejs)
  - [fn_AllDayAsUTC.sql](#fn_alldayasutcsql)
  - [sp-UserTimezone.ps1](#sp-usertimezoneps1)
- [Things to know about SharePoint Datetime Fields](#things-to-know-about-sharepoint-datetime-fields)
- [From SharePoint to SQL](#from-sharepoint-to-sql)
- [Querying Handshake Classes with UTC Dates](#querying-handshake-classes-with-utc-dates)
  - [Identifying a field as a UTC field](#identifying-a-field-as-a-utc-field)
  - [How Handshake Translates Dates to/from UTC](#how-handshake-translates-dates-tofrom-utc)
  - [Returned Values for UTC and Non-UTC datetime fields](#returned-values-for-utc-and-non-utc-datetime-fields)
- [Presenting Date and Times in Kendo Controls](#presenting-date-and-times-in-kendo-controls)

> Special Note: All Day Events have unique challenges when dealing with time zones and presenting those events correctly to people from Berlin to Honolulu.  The details are covered in the guide [The Christmas Day Challenge](christmas-day-challenge.md) 

## Included files

### sample.js 
Includes javascript functions that may be used to properly parse an All Day Event to the users current time zone. And one that can be used in an HTML5Scheduler widget that will properly assign an all day event to the day relative to the users current time zone. Where current time zone = the time zone set on the users device.

### fn_AllDayAsUTC.sql
A Sql function that will recast an all day event to be midnight UTC **regardless** of the time zone of the user that created the SharePoint event item. 

### sp-UserTimezone.ps1 
SharePoint Management Module script to get and set the timezone for a specific user 
```powershell
    . ./SPUserTimeZone.ps1 
    Add-PSSnapin Microsoft.SharePoint.PowerShell 
    $portalUrl = 'https://portal2021.handshakedemo.com'
    $me = "i:0#.w|handshakedemo\steve.mchargue" 
    Get-SPUserTimeZone -portalUrl $portalUrl -userLogin $me
    Set-SPUserTimeZone -portalUrl $portalUrl -userLogin $me -timezoneID 11
    Get-SPTimeZones -portalUrl $portalUrl | Sort-Object -property ID | Format-Table id, description
```

## Things to know about SharePoint Datetime Fields 
When entering dates, even fields marked as "date only", SharePoint will store the timestamp as a UTC value based on the user's SharePoint time zone setting. This is true for all SharePoint date fields, even those not contained in Event list.  SharePoint **does not** take the user's current browser settings into account.  It relies exclusively on one of two settings:

1. The time zone setting for the current user in their site collection profile
2. Or the time zone setting of the SharePoint site collection.

> There is ample information available on the internet with regards to SharePoint and time zones, bizarrely almost none of it from Microsoft.  Here is a source I trust for [Setting proper SharePoint Time Zones for users](https://sharepointmaven.com/sharepoint-time-zone/).  

> A sample powershell script is included in this solution that you can modify to set the Site Collection time zone settings for your existing users, assuming you don't with to tell your lawyers to click here, here, here and initial here to set your proper time zone. 

The rest of this guide assumes that your Chicago Users are set in SharePoint for *(UTC-06:00) Central Time (US & Canada)* and your Berlin Users are set for *(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna*, etc...

## From SharePoint to SQL
ListGuru, for on-prem SharePoint, and ListMirror, for SharePoint Online, is responsible for replicating SharePoint list items to SQL tables. SharePoint Event Lists are a special case for both of these tools. An event is treated differently when it is created/updated in SQL based on whether:

* The event is a single event with a start/end time that exists within a single calendar day.
* The event is a single event set for *all day*
* The event is a single event with a start/end time that spans two or more calendar days.
* The event is a recurring event 
* The event is a recurring event set for all day
* The event is a recurring event, with exceptions

To demonstrate this the following events were added to a SharePoint Event List, with the test user account time zone set to Chicago.

- **Alpha** - Single Event occurring at 1:00pm - 2:00pm on April 12, 2021
- **Beta** - Single Event set for all day, April 12, 2021 
- **Gamma** - Single Event from 1:00pm April 13 to 2:00pm April 14, 2021 
- **Delta** - Recurring Event every Thursday from 1:00pm - 2:00pm for 4 weeks.  The 3rd week it is moved to 2pm 
- **Epsilon** - Recurring Event, all day, every Friday for 4 weeks.  4th week set from 8:00pm to 12pm
- **Zeta** - A single, all day event that spans Monday April 19th to Friday April 23rd, 2021. 
- **Eta** - A recurring lunch event the first Monday of every month, for 12 months. 

These entries will result in the following rows being created in the ListGuru SQL table. Note that all times have been stored as UTC values. 1:00pm = 18:00 and the beginning of the day in Chicago is store as 05:00 hours for April 12. These times vary based on daylight savings time, as you can set if event "Eta" below.

| Title | EventDate | EndDate | __EventType | fAllDayEvent | fRecurrence |
|---------|-------------------------|-------------------------|:-----------:|:------------:|:-----------:|
| Alpha | 2021-04-12 **18**:00:00.000 | 2021-04-12 **19**:00:00.000 |  0  | 0  |  0  |
| Beta  | 2021-04-12 **05**:00:00.000 | 2021-04-13 **04**:59:00.000 |  0  | 1  |  0  |
| Gamma | 2021-04-13 **18**:00:00.000 | 2021-04-14 **03**:59:59.000 |  -2 | 0  |  0  |
| Gamma | 2021-04-14 **04**:00:00.000 | 2021-04-14 **19**:00:00.000 |  -2 | 0  |  0  |
| Gamma | 2021-04-13 **18**:00:00.000 | 2021-04-14 **19**:00:00.000 |  -1 | 0  |  0  |
| Delta | 2021-04-15 **18**:00:00.000 | 2021-05-06 **19**:00:00.000 |  1  | 0  |  1  |
| Delta | 2021-04-15 **18**:00:00.000 | 2021-04-15 **19**:00:00.000 |  5  | 0  |  1  |
| Delta | 2021-04-22 **18**:00:00.000 | 2021-04-22 **19**:00:00.000 |  5  | 0  |  1  |
| Delta | 2021-05-06 **18**:00:00.000 | 2021-05-06 **19**:00:00.000 |  5  | 0  |  1  |
| Delta | 2021-04-29 **19**:00:00.000 | 2021-04-29 **20**:00:00.000 |  4  | 0  |  1  |
| Epsilon | 2021-04-23 **05**:00:00.000 | 2021-04-24 **04**:59:00.000 |  5  | 1  |  1  |
| Epsilon | 2021-05-07 **05**:00:00.000 | 2021-05-08 **04**:59:00.000 |  5  | 1  |  1  |
| Epsilon | 2021-04-16 **05**:00:00.000 | 2021-05-08 **04**:59:00.000 |  1  | 1  |  1  |
| Epsilon | 2021-04-16 **05**:00:00.000 | 2021-04-17 **04**:59:00.000 |  5  | 1  |  1  |
| Epsilon | 2021-04-30 **13**:00:00.000 | 2021-04-30 **17**:59:00.000 |  4  | 0  |  1  |
| Zeta | 2021-04-20 **04**:00:00.000 | 2021-04-21 **03**:59:59.000 | -2 | 1 | 0 |
| Zeta | 2021-04-21 **04**:00:00.000 | 2021-04-22 **03**:59:59.000 | -2 | 1 | 0 |
| Zeta | 2021-04-22 **04**:00:00.000 | 2021-04-23 **03**:59:59.000 | -2 | 1 | 0 |
| Zeta | 2021-04-23 **04**:00:00.000 | 2021-04-24 **04**:59:00.000 | -2 | 1 | 0 |
| Zeta | 2021-04-19 **05**:00:00.000 | 2021-04-24 **04**:59:00.000 | -1 | 1 | 0 |
| Zeta | 2021-04-19 **05**:00:00.000 | 2021-04-20 **03**:59:59.000 | -2 | 1 | 0 |
| Eta  | 2021-01-04 **18**:00:00.000 | 2021-12-06 **19**:00:00.000 | 1  | 0 | 1 |
| Eta  | 2021-01-04 **18**:00:00.000 | 2021-01-04 **19**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-02-01 **18**:00:00.000 | 2021-02-01 **19**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-03-01 **18**:00:00.000 | 2021-03-01 **19**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-04-05 **17**:00:00.000 | 2021-04-05 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-05-03 **17**:00:00.000 | 2021-05-03 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-06-07 **17**:00:00.000 | 2021-06-07 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-07-05 **17**:00:00.000 | 2021-07-05 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-08-02 **17**:00:00.000 | 2021-08-02 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-09-06 **17**:00:00.000 | 2021-09-06 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-10-04 **17**:00:00.000 | 2021-10-04 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-11-01 **17**:00:00.000 | 2021-11-01 **18**:00:00.000 | 5  | 0 | 1 |
| Eta  | 2021-12-06 **18**:00:00.000 | 2021-12-06 **19**:00:00.000 | 5  | 0 | 1 |

The key to understanding these results, and when certain rows should be included or excluded in your query, is in understanding the event type rules that ListGuru/Mirror is following:


| Type  | Description  | fRecurrence | fAllDayEvent  | EventType |
|----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------|-----------------|---------------|
| Single event |  An event created with the All Day Event and Recurrence checkboxes unselected.  |  False  |  False  |  0  |
| All-day event  |  An event created with the All Day Event checkbox selected.  |  False  |  True |  0  |
| Recurring event |  An event created with the Recurrence checkbox selected.  In the SharePoint calendar view, it has a recurrence icon in the All Events view.  Appears as a single master event on the All Events view, but as recurring instances on the Current Events and Calendar views.  |  True |  False  |  1  |
| Recurring all-day event  |  Same as above, but with the All Day Event checkbox selected at creation time.  |  True |  True |  1  |
|  Single Events, MultiDay, Single Row  |  Special Handshake value - this is the single row that spans the start and end date of the event  |  |  | -1  |
|  Single Event, MultiDay MultiRow |  Special Handshake value, a row is returned for each day that an event occurs |  |  |  -2 |
| Recurrence exception  |  Created by editing an instance of a recurring event.  Has a strike-through recurrence icon in the All Events view.  |  True |  False  |  4  |
| All-day recurrence exception |  Same as above, but created by editing an instance of an all-day recurring event. |  True |  True |  4  |
| Deleted instance of a recurring event  |  Created by deleting a instance of a recurring event.  Title is prefixed with “Deleted:” in the All Events view, and is hidden in the Current Events and Calendar views.  |  True |  False  |  3  |
| Deleted instance of an all-day recurring event  |  Same as above, but created by deleting an instance of an all-day recurring event.  |  True |  True |  3  |
|  Recurring Event Instance | Unique instance of a recurring event item  | True |  |  5  |

To query this SQL table you must understand the Event Types that are created, and query according to your specific requirements. Most notably, whether you want events that span days to be treated as a single row, e.g. a list of upcoming events, or as a row for each day, as you would find in an agenda view. 

> **There is likely no real use case where you would query for all rows in the table without excluding some event types.** 

You will find it a valuable exercise to create several test events, with your SharePoint time zone set to different values, and evaluate the results in your ListGuru/Mirror tables. 

## Querying Handshake Classes with UTC Dates
Beginning with Handshake 3.8 a facility in included for automatically handling and appropriately translating date values that are stored in UTC. The support includes reporting the date in an appropriate time zone and translating filter values to UTC for SQL filters.

### Identifying a field as a UTC field 
The “field categories” portion of field in the Handshake toolkit is used to indicate that a field holds a UTC value. To make this selection go to the “Categories” tab of a field and check the “Universal Time Code” flag under “Field Type” as shown here: 

![images/utcfield.png](images/utcfield.png)

### How Handshake Translates Dates to/from UTC 
Handshake has several options for determining what time zone should be used for translating dates. For each request Handshake selects a time zone by looking for a value in the following sources: 

1. An input property sent to the skin named _HS_TimeZoneID. 
2. A user property from HSUsers named TimeZoneID. 
3. An HSApplicationOption entry with a key name of TimeZoneID. 
4. The default time zone for the Handshake server. 

Regardless of the source for the value, the list of values can be found in the "Name of Time Zone" column of the [list here](https://docs.microsoft.com/en-us/previous-versions/windows/embedded/ms912391(v=winembedded.11)).

> Note: while the list from the link above should be accurate enough for most business purposes, it is no longer maintained by Microsoft.  The most up to date and accurate list would be returned from the windows 10 terminal command ``` tzutil /l ```

The **best practice** would be #2 - setting the TimeZoneID in the HSUsers Class as a case statement using the user's primary office location.  For example:

```sql
CASE u.OfficeName 
  WHEN 'Seattle' THEN 'Pacific Standard Time'
  WHEN 'Dallas' THEN 'Central Standard Time'
  WHEN 'Atlanta' THEN 'Eastern Standard Time'
  WHEN 'London' THEN 'GMT Standard Time'
  WHEN 'Berlin' THEN 'W. Europe Standard Time'
  WHEN 'Singapore' THEN 'Singapore Standard Time'
  ELSE 'GMT Standard Time' /* or some other appropriate fall back */
END
```
Of course, your requirements may dictate a different option.

With the HSTimeZoneID properly set, the Handshake query engine will form sql expressions that will take into account the time zone of the user requesting the data.  

As an example, When logged into the HSServer Query Tool as a New York User you will see for this HS Query
```SQL
SELECT 
    title, eventDateStart
 FROM 
    RNConnect_FirmEvents!<ALL>
 WHERE 
    @eventDateStart  = '4/12/2021'
```
The following SQL is generated:
```SQL 
SELECT ev.[Title] [title], 
    ev.[EventDate] [eventDateStart] 
FROM Connect_FirmEvents ev  
WHERE (ev.[EventDate] >='2021-04-12 04:00:00' AND ev.[EventDate] <'2021-04-13 04:00:00') 
```
And for a Seattle User the same query results in this SQL Expression:
```SQL 
SELECT ev.[Title] [title], 
    ev.[EventDate] [eventDateStart] 
FROM Connect_FirmEvents ev  
WHERE (ev.[EventDate] >='2021-04-12 07:00:00' AND ev.[EventDate] <'2021-04-13 07:00:00') 
```

> The best tool for evaluating, and thereby understanding, the effect of different time zone values is to use the Handshake Server Tool run from an RDP session to your development Handshake Server.

### Returned Values for UTC and Non-UTC datetime fields
Setting the Field Category to UTC and the User's HSTimeZoneID effects how those fields are queried. It will also effect the result value returned by the ODATA service. It will not however alter the value returned by server side elements like a GetResultSet. That is an important distinction to keep in mind when developing your solution. 

To demonstrate this, consider a HS Class, demo_testData, generated from the following SQL
```SQL
WITH CTE AS 
( Select GetDate()  as [d1] )
SELECT	cte.d1 d1_notutc,	cte.d1 d1_utc
FROM	cte 
```
In this example, both fields will be returned as the current date and time of the SQL Server. In our class we will set only d1_utc to have the category flag of "Universal Time Code".

This handshake query, executed in the context of a pacific time user:
```sql
select d1_utc, d1_notutc  from demo_dataTest 
where @d1_utc='4/12/2021' OR d1_notutc='4/12/2021'
```
Will produce this SQL 
```sql
;WITH CTE AS  
( Select GetDate()  as [d1] ) 
SELECT cte.d1 [d1_utc], cte.d1 [d1_notutc] 
FROM cte  
WHERE (cte.d1>='2021-04-12 07:00:00' AND cte.d1<'2021-04-13 07:00:00') 
   OR (cte.d1>='2021-04-12' AND cte.d1<'2021-04-13') 
```
The Non-UTC date field will not attempt to apply any time zone. And we are purposefully saying one of these values is UTC and one is not, even though they both have the same raw value. 

Now this query, which includes an exact time in the filter, will convert the supplied time relative to the UTC value for the first field, and the exact value for the 2nd:
```
select d1_utc, d1_notutc  from demo_dataTest 
where @d1_utc = '4/12/2021 04:00' OR d1_notutc  = '4/12/2021 04:00'
```
```
;WITH CTE AS  
( Select GetDate()  as [d1] ) 
SELECT cte.d1 [d1_utc], cte.d1 [d1_notutc] 
FROM cte  
WHERE (cte.d1='2021-04-12 11:00:00') OR (cte.d1='2021-04-12 04:00:00') 
```
In all instances, the server side results for the date and time are returned the same for both fields. 

| d1_utc |   d1_notutc  |
| ---------------- |  ---------------- |
| 4/12/2021 5:42:5 |  4/12/2021 5:42:5 |

But when you review the results when the same class is presented in a skin, and rendered by a user with a browser time zone set to Eastern Time, you will see a different story.

Skin (note some modifications were made for clarity, not a valid HS SKin )
```xml
  <description />
  <scripts />
  <hiddencontrols>
    <getresultset allowupdate="N" name="dtest" cols="d1_notutc,d1_utc" mpinfo="demo_dataTest" />
  </hiddencontrols>
  <body type="standardbody">
    <div text="d1_notutc = {=dtest.d1_notutc}"></div>
    <div text="d1_utc = {=dtest.d1_utc}" />
    <div>
      <html5grid name="g" mpinfo="demo_dataTest">
        <columns.Column field="d1_notutc" title="Not UTC" 
        template="#: kendo.toString(kendo.parseDate(d1_notutc),'M/dd/yyyy h:mm:ss tt') #" />
        <columns.Column field="d1_utc" title="UTC" 
        template="#: kendo.toString(kendo.parseDate(d1_utc),'M/dd/yyyy h:mm:ss tt') #" />
      </html5grid>
    </div>
  </body>
</page>
``` 
Results, as presented in the Content Designer Preview:

![sample](images/sampleskin1.png)

In the server side results and the "Not UTC" column in the kendo grid, the results were returned based on the current time of the SQL Server. In the Grid, the field with the UTC Field flag set, the results were provided by the ODATA service as UTC, and coverted by kendo to Eastern Time. 

## Presenting Date and Times in Kendo Controls
Regardless of the HSTimeZoneID the Handshake ODATA Web Service will deliver a datetime flagged as UTC as a string value that is easily parsed by the Kendo library in the form:
```json
"/Date(1618170877090)/"
```
That number is the number of milliseconds since Jan 1, 1970 and will **always** be interpreted as a UTC datetime.  But, keep in mind that value will be parsed in both native JavaScript and the Kendo date parser into the time zone of the browser.

So for the value 1618170877090 which for UTC = Sun Apr 11 2021 19:54:37 GMT+0000, the following will be true on a machine set to New York time:
```javascript
new Date(1618170877090) 
// output is  Sun Apr 11 2021 15:54:37 GMT-0400 (Eastern Daylight Time)
kendo.toString(kendo.parseDate("/Date(1618170877090)/"),"MMM d, yyyy h:mm tt zzz"); 
// output is  Apr 11, 2021 3:54 PM -04:00
```

As shown, the ODATA string is easily parsed to a javascript date by the kendo command **kendo.parseDate**.  You will see the following bit of code in almost every HTML5ListView/Template found:
```javascript
# var d = kendo.toString(kendo.parseDate(dateField),"MMM d, yyyy"); #
<div>Date: #: d # </div>
```

In summary, when dealing with datetime fields stored in SQL you want to 

- Set the field category to UTC in the handshake class
- Think through your requirements for filtering rows from the table
- Use kendo widgets (grid, scheduler or listview) to displays the data.

At this point, it is probably not worth the effort to attempt to use server side controls like GetResultSet or Paged Repeater to display datasets that include a UTC based datetime field. 