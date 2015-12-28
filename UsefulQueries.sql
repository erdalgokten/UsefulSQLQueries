
-- Active database connections
select
	c.encrypt_option,
	s.login_name,
	*
from
	sys.dm_exec_sessions s
join
	sys.dm_exec_connections c
on
	s.session_id = c.session_id
where
	1=1
	and c.client_net_address = '<IPAddress>'
	and s.login_time > '<LoginTime>'
	and s.login_name = '<LoginName>'
order by
	s.login_time desc
go;


-- Find a keyword in any object definition
select
	distinct so.Name
from
	sysobjects so (nolock)
inner join
	syscomments sc (nolock)
on
	so.Id = sc.id
	and so.[Type] in ('P', 'TF')
	and sc.[Text] like '%<keyword>%'
order by
	so.Name
go;


-- Find last insert/update/delete on a table
select
	*
from
	sys.objects o
join
	sys.dm_db_index_usage_stats s
on
	o.object_id = s.object_id
where
	s.last_user_update is not null
	and o.type = 'U'
order by
	s.last_user_update desc
go;


-- Find last execution time of an SP
select
	*
from
	sys.procedures p
join
	sys.dm_exec_procedure_stats s
on
	p.object_id = s.object_id
where
	s.last_execution_time is not null
	and p.is_ms_shipped = 0
order by
	s.last_execution_time desc
go;


-- Find dormant tables
select
	name
from
	sys.objects
where
	[type] = 'U'
	and object_id not in
	(
		select
			distinct o.object_id
		from
			sys.objects o
		join
			sys.dm_db_index_usage_stats s
		on
			o.object_id = s.object_id
		where
			s.last_user_update is not null
			and o.type = 'U'
	)
order by
	name
go;


-- Find empty tables
select
	t.name as TableName,
	p.[rows] as RowCounts
from
	sys.tables t
inner join
	sys.partitions p
on
	t.object_id = p.object_id
where
	1=1
	and t.is_ms_shipped = 0
	and p.[rows] = 0
group by
	t.Name, p.[Rows]
order by
	t.Name
go;


-- Query job history
exec msdb.dbo.sp_help_jobhistory
	@job_name = N'<JobName>'
go;


-- Query job steps
exec msdb.dbo.sp_help_jobstep
	@job_name = N'<JobName>'
go;


-- Index rebuild time
select
	STATS_DATE(
		OBJECT_ID('<TableName>'),
		(select index_id from sys.indexes where name = '<IndexName>')
	)
go;

-- Query locks on the database
select
	L.request_session_id AS SPID,
	DB_NAME(L.resource_database_id) AS DatabaseName,
	O.Name AS LockedObjectName,
	P.object_id AS LockedObjectId,
	L.resource_type AS LockedResource,
	L.request_mode AS LockType,
	ST.[text] AS SqlStatementText,
	ES.login_name AS LoginName,
	ES.host_name AS HostName,
	TST.is_user_transaction AS IsUserTransaction,
	AT.name AS TransactionName,
	CN.auth_scheme AS AuthenticationMethod
from
	sys.dm_tran_locks L
	join sys.partitions P on P.hobt_id = L.resource_associated_entity_id
	join sys.objects O on O.object_id = P.object_id
	join sys.dm_exec_sessions ES on ES.session_id = L.request_session_id
	join sys.dm_tran_session_transactions TST on ES.session_id = TST.session_id
	join sys.dm_tran_active_transactions AT on TST.transaction_id = AT.transaction_id
	join sys.dm_exec_connections CN on CN.session_id = ES.session_id
	cross apply sys.dm_exec_sql_text(CN.most_recent_sql_handle) AS ST
where
	resource_database_id = db_id()
order by
	L.request_session_id
go;


-- Quoted identifier usage
set quoted_identifier off

select "asdfasd'asasd"
select 'asdfasd"asasd'

set quoted_identifier on
go;


-- CTE (Common Table Expression) usage
;with login_logout_cte (SessionNumber, IP, LOGGEDIN, LOGGEDOUT) as
(
	select
		SessionNumber,
		MAX(ClientIP) as IP,
		MAX(LoginTime) as LOGGEDIN,
		MAX(LogoutTime) as LOGGEDOUT
	from
		DummyTable (nolock)
	where
		CustomerId = @CustomerId
	group by
		SessionId
)
select * from login_logout_cte order by LOGGEDIN
go;


-- Index physical stats for a given table
select
	*
from
	sys.dm_db_index_physical_stats(
		DB_ID(),
		OBJECT_ID(N'<TableName>'), NULL, NULL, 'LIMITED'
	)


select
	t.name,
	i.name,
	s.*
from
	sys.dm_db_index_physical_stats(
		DB_ID(N'<DatabaseName>'),
		OBJECT_ID(N'<TableName>'), NULL, NULL, 'LIMITED'
	) s
join
	sys.tables t
on
	s.object_id = t.object_id
join
	sys.indexes i
on 
	s.index_id = i.index_id
	and s.object_id = i.object_id
go;