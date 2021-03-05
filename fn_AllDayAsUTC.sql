CREATE FUNCTION [dbo].[fn_AllDayAsUTC](@isallday as [int], @dt as [datetime], @asEnd as [int])
/*
INPUT
	isAllDay: 1 or 0, if 1 then the event is set as an All Day Event
	dt: date and time of the event, stored as UTC relative to the timezone of the author or the SP server.
	asEnd: 1 or 0, return the start time of an all day event, or the end time. 
*/
RETURNS [datetime] AS
BEGIN
	DECLARE @dt1 [datetime]
	
	IF (@isAllDay=0) OR (DATEPART(HOUR,@dt) = 0 AND @asend=0) OR (DATEPART(HOUR,@dt) = 23 AND @asEnd=1) 
		SET @dt1 = @dt 
	ELSE
	BEGIN
		SET @dt1 = CASE 
	
			-- if the hour is < 11 (or 10 if end date) then the date part is correct, just convert it to 00:00 hours
			WHEN @isallday = 1 AND DATEPART(HOUR,@dt) < (11 - @asend)
				THEN DATEADD(Day, 0, DATEDIFF(Day, 0, @dt))

			-- if the hour is 11:00 or greater, then the date part is a day behind what we want, convert to 00:00 hours and add a day.
			WHEN @isallday = 1 
				THEN DATEADD(Day, 1, DATEDIFF(Day, 0, @dt))

			ELSE @dt
		END	

		IF @asEnd = 1 -- subtract 1 minute when this is the end date of an all day event
			SET @dt1 = DATEADD(MINUTE, -1, @dt1)

	END 
	RETURN @dt1 

END
GO