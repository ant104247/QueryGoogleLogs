// find out most time consuming cypher statements

MATCH (row:Query)
return  row.query as query, 
count(*) as query_cnts, 
min(row.elapsedTimeMs) as min_elapsedTimeMs, 
max(row.elapsedTimeMs) as max_elapsedTimeMs, 
avg(row.elapsedTimeMs) as average_elpased_time, 
sum(row.elapsedTimeMs) as total_elapsed_time
order by total_elapsed_time desc
