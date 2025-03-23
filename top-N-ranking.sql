/*
What are the top five (ranked in decreasing order) single-channel media types that correspond to the most money the grocery chain had spent on its promotional campaigns? media_type can contain mutliple values separated by a comma, so single channel is when media_type only has one value.
*/

select cte.*
from (
select media_type as single_channel_media_type, sum(cost) as total_cost
from promotions p
where media_type not like '%, %'
group by media_type
order by total_cost desc
) cte
limit 5
