select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go

alter security policy rls.SensitiveDataPolicy
with (state = on)
go

select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go

exec sys.sp_set_session_context @key = N'user-hash-id', @value = -6134311, @read_only = 0;  
go

select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go

exec sys.sp_set_session_context @key = N'user-hash-id', @value = 1225328053, @read_only = 0;  
go

select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go

exec sys.sp_set_session_context @key = 'user-hash-id', @value = 0, @read_only = 0;  
go

select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go
