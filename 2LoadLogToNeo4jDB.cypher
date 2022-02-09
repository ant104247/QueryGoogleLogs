
MATCH (q:Query) DETACH DELETE (q);
CALL apoc.periodic.iterate(
		"CALL apoc.load.json('file:///downloaded-query-log.json')
				YIELD value AS row", 
		"CREATE (q:Query) 
			SET     q.insertId = row.insertId,
				q.allocatedBytes= row.jsonPayload.allocatedBytes,
			    	q.dbid= row.jsonPayload.dbid,
			    	q.database=row.jsonPayload.database,
			    	q.elapsedTimeMs= row.jsonPayload.elapsedTimeMs,
			    	q.event = row.jsonPayload.event,
				q.id = row.jsonPayload.id,
				q.message = row.jsonPayload.message,
				q.pageHits = row.jsonPayload.pageHits,
				q.podname = row.jsonPayload.podname,
				q.query = row.jsonPayload.query,
				q.runtime = row.jsonPayload.runtime,
				q.source = row.jsonPayload.source,
				q.cluster_name = row.cluster_name,
				q.severity = row.severity,
				q.timestamp = row.timestamp",
		{batchSize:200, parallel:false})


CREATE INDEX query IF NOT EXISTS FOR (q:Query) ON (q.Query)


