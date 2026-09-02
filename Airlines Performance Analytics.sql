use project1;

select *from maindata;

create view main AS
		select `%Distance Group ID` as Distance_Group_ID,
			   `# Departures Scheduled` as Departures_Scheduled,
               `# Departures Performed` as Departures_Performed,
               `# Payload` as Payload, Distance,
               `# Available Seats` as Available_Seats,
               `# Transported Passengers` as Transported_Passengers,
               `Carrier Code` as Carrier_Code,
               `Carrier Name` as Carrier_Name,
               `Origin Airport Code` as Origin_Airport_Code,
               `Origin City` as Origin_City,
               `Origin State Code` as Origin_State_Code,
               `Origin State` as Origin_State,
               `Origin Country Code` as Origin_Country_Code,
               `Origin Country` as Origin_Country,
               `Destination Airport Code` as Destination_Airport_Code,
               `Destination City` as Destination_City,
               `Destination State Code` as Destination_State_Code,
               `Destination State` as Destination_State,
               `Destination Country Code` as Destination_Country_Code,
               `Destination Country` as Destination_Country,
               Year, `Month (#)` as MonthNumber,
               Day, `From - To City` as From_To_City
               from maindata;
			
create table Airline as select *from main;

select *from airline;

Alter table airline add F_Date Date after Day,
					add Month_Name int after F_Date,
                    add QuarterNo int after Month_Name,
                    add YearMonth varchar(20) after QuarterNo,
                    add WeekdayNo int after QuarterNo,
                    add Weekdayname varchar(20) after WeekdayNo,
                    add FinancialMonth int after WeekdayName,
                    add FinancialQuarter int after FinancialMonth;
               
update airline set F_Date = str_to_date(concat(Year,'-',MonthNumber,'-',Day),'%Y-%m-%d');
               
alter table airline modify column Month_name varchar(20);
alter table airline modify column QuarterNo varchar(5);
alter table airline modify column FinancialQuarter varchar(5);

update airline set Month_Name = monthname(F_Date);
               
update airline set QuarterNo = concat('Q',quarter(F_Date)),
				   YearMonth = date_format(F_Date,'%Y-%b'),
				   WeekdayNo = dayofweek(F_Date),
                   WeekdayName = dayname(F_Date),
                   FinancialMonth = case
										when month(F_Date) >9 then month(F_Date) - 9
                                        else month(F_Date) + 3
									end,
				   FinancialQuarter = case
										when month(F_Date) in ( 10,11,12) then 'Q1'
                                        when month(F_Date) in ( 1,2,3) then 'Q2'
                                        when month (F_Date) in ( 4,5,6) then 'Q3'
                                        else 'Q4'
									end;
                                    
select *from airline;
               
 

############################################# Load Factor Calculation - By Year, Month and Quarter ##########################################

alter table airline add column Financial_Year int after FinancialQuarter;

update airline set Financial_Year = case
										when month(F_Date) < 10 then year(F_Date)
                                        else year(F_Date) + 1
									end;

															# For Year

select concat(Financial_Year-1,'-',Financial_Year) as Financial_Year, 
		sum(Transported_Passengers) as Total_Passengers, 
        sum(Available_Seats) as Total_Seats,
		concat((sum(Transported_Passengers) /sum(Available_Seats))*100,' %') as Load_Factor_By_Year from airline
group by Financial_Year order by Financial_Year asc ;
            
															# For Month
            
select FinancialMonth, sum(Transported_Passengers) as Total_Passengers, sum(Available_Seats) as Total_Seats,
			  concat((sum(Transported_Passengers) /sum(Available_Seats))*100,' %') as Load_Factor_By_Month from airline
              group by FinancialMonth order by FinancialMonth;
              
															# For Quarter
              
select FinancialQuarter, sum(Transported_Passengers) as Total_Passengers, sum(Available_Seats) as Total_Seats,
				  concat((sum(Transported_Passengers) /sum(Available_Seats))*100,' %') as Load_Factor_By_Quarter from airline
                  group by FinancialQuarter order by FinancialQuarter;
               
               
															# All in One
                                                            
with MonthStats as (
select 
        Financial_Year,
        FinancialQuarter,
        FinancialMonth,
        SUM(Transported_Passengers) AS Month_Pass,
        SUM(Available_Seats) AS Month_Seats
    from airline
    group by Financial_Year, FinancialMonth, FinancialQuarter
					)
                    
select 
	Financial_Year, FinancialQuarter, FinancialMonth,
    concat((sum(Month_Pass) over ( partition by Financial_Year) / sum(Month_Seats) over ( partition by Financial_Year)) *100,' %' ) as Year_Load,
	concat((sum(Month_Pass) over ( partition by Financial_Year, FinancialQuarter ) /
		   sum(Month_Seats) over ( partition by Financial_Year, FinancialQuarter )) * 100,' %') as QuarterLoad,
	concat((Month_Pass / Month_Seats) *100,' %') as MonthLoad
from MonthStats order by Financial_Year, FinancialQuarter, FinancialMonth;
   
   
   
   
######################################### Load Factor Calculation - By Carrier Name ######################################################

select Carrier_Name, sum(Transported_Passengers) as Total_Passengers, sum(Available_Seats) as Total_Seats,
					 concat((sum(Transported_Passengers) /sum(Available_Seats))*100,' %') as Load_Factor_By_Carrier from airline
                     group by Carrier_Name order by Load_Factor_By_Carrier desc;
                     
	
######################################### Top 10 Carrier Names based on Passengers Preference ############################################

/* select Carrier_Name, sum(Transported_Passengers) as Total_Passengers
		from airline group by Carrier_Name order by Total_Passengers desc limit 10; */
                     
select * from ( 
				select Carrier_Name, sum(Transported_Passengers) as Total_Passengers,
				dense_rank() over ( order by sum(Transported_Passengers) desc ) as Preference
				from airline group by Carrier_Name
			  ) as Temp
	where Preference < 11;
                


##################################### Top routes From to city based on No of flights ###################################################

/* select From_to_City, sum(Departures_Performed) as Total_Flights 
	from airline group by From_to_City order by Total_Flights desc; */


select * from (
				select From_To_City, sum(Departures_Performed) as Total_Flights ,
				dense_rank() over ( order by sum(Departures_Performed) desc ) as Ranking
			    from airline group by From_To_City
			  ) as Temp
		where Ranking < 6;



############################################## Load occupied on weekend and weekdays #######################################################

select case
			when weekdayno in (2,3,4,5,6) then 'Weekday'
            else 'Weekend'
		end as DayType,
        sum(Transported_Passengers) as Total_Passengers, sum(Available_Seats) as Total_Seats,
        concat((sum(Transported_Passengers) / sum(Available_Seats))*100,' %') as Load_Factor
from airline group by DayType order by Load_Factor desc;
		
        

/* 
with LoadFactorsOnDays AS (
    select 
        concat((sum(case when weekdayno in (1,7) then Transported_Passengers end ) /
		sum(case when weekdayno in (1,7) then Available_Seats end)) *100,' %') as Weekend_Load,
        
        concat((sum(case when weekdayno not in (1,7) then Transported_Passengers end ) /
		sum(case when weekdayno not in (1,7) then Available_Seats end)) *100,' %') as Weekday_Load
        
    from airline
)

select Weekday_Load, Weekend_Load from LoadFactorsOnDays; */

		
        
        
      
########################################### No of flights based on distance group ######################################################
        
select Distance_Group_ID, sum(Departures_Performed) as Total_Flights from airline
			group by Distance_Group_ID order by Total_Flights desc;




########## Use the filter to provide a search capability to find the flights between Source Country, Source State, Source City to
#		   Destination Country , Destination State, Destination City ######################################################################

select *from airline;

delimiter &&

create procedure FindFlightInfo ( in OriginCounty1 varchar(20), in OriginState1 varchar(20), in OriginCity1 varchar(20),
				in Destination_Country1 varchar(20), in Destination_State1 varchar(20), in Destination_City1 varchar(20))
		BEGIN
			select OriginCounty1 as From_Country, OriginState1 as From_State, OriginCity1 as From_City, 
				   Destination_Country1 as To_Country, Destination_State1 as To_State, Destination_City1 as To_City,
			From_To_City, sum(Departures_Performed) as Total_Departured_Flights,
            sum(Departures_Scheduled) as Scheduled_Flights
            from airline
		where OriginCounty1 = Origin_Country AND OriginState1 = Origin_State AND OriginCity1 = Origin_City AND
			  Destination_Country1 = Destination_Country AND Destination_State1 = Destination_State AND Destination_City1 = Destination_City
              group by From_To_City;
		END &&
        
Delimiter ;

drop procedure FindFlightInfo;

call FindFlightInfo('United States','Alaska','Red Dog, AK','United States','Alaska','Kotzebue, AK');



select *from airline;





