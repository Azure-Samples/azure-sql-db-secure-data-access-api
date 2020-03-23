create user MiddleTierUser with password = 'a987REALLY#$%TRONGpa44w0rd';
alter role db_owner add member MiddleTierUser;
go

drop security policy if exists rls.SensitiveDataPolicy;
drop function if exists rls.fn_SecurityPredicate;
drop table if exists rls.SensitiveDataPermissions;
drop table if exists dbo.EvenMoreSensitiveData;
drop table if exists dbo.SensitiveData;
go

drop schema if exists rls;
go
create schema rls;
go

create table dbo.SensitiveData
(
    Id int not null constraint pk__SensitiveData primary key,
    FirstName nvarchar(100) not null,
    LastName nvarchar(100) not null,
    ReallyImportantData nvarchar(max) not null check (isjson(ReallyImportantData)=1)
)
go

create table dbo.EvenMoreSensitiveData
(
    Id int not null constraint pk__EvenMoreSensitiveData primary key nonclustered,
    SensitiveDataId int not null foreign key references dbo.SensitiveData(Id),
    SomeData1 int not null,
    SomeData2 datetime2 not null,
    SomeData3 nvarchar(100) not null
)
go

create clustered index ixc on dbo.EvenMoreSensitiveData (SensitiveDataId)
go

create table rls.SensitiveDataPermissions
(
    UserName sysname not null,
    SensitiveDataId int not null foreign key references dbo.SensitiveData(Id),
    HasAccess bit not null default(0),
    constraint pk__rls_SensitiveDataPermissions primary key clustered (UserName, SensitiveDataId)
)
go

insert into dbo.SensitiveData values
(1, 'Davide', 'Mauri', '{"SuperPowers":"Fly"}'),
(2, 'John', 'Doe', '{"SuperPowers":"Laser Eyes"}')
go

insert into dbo.EvenMoreSensitiveData values
(1, 1, 10, sysdatetime(), 'Some more secret info here'),
(2, 1, 20, sysdatetime(), 'and here'),
(3, 1, 30, sysdatetime(), 'and look, eve here!'),
(4, 2, 100, sysdatetime(), 'Nothing to see here'),
(5, 2, 200, sysdatetime(), 'unless you look very close!')
go

insert into rls.SensitiveDataPermissions values
('damauri', 1, 1),
('jdoe', 2, 1)
go

create function rls.fn_securitypredicate(@SensitiveDataId int)  
returns table
with schemabinding
as
return
select 
    HasAccess
from
    rls.SensitiveDataPermissions
where
    database_principal_id() = database_principal_id('MiddleTierUser')
and     
    UserName = session_context(N'username')
and
    SensitiveDataId = @SensitiveDataId
go

select * from dbo.SensitiveData
go

create security policy rls.SensitiveDataPolicy
add filter predicate rls.fn_SecurityPredicate(Id) on dbo.SensitiveData,
add filter predicate rls.fn_SecurityPredicate(SensitiveDataId) on dbo.EvenMoreSensitiveData
with (state = on);  

select * from dbo.SensitiveData
select * from dbo.EvenMoreSensitiveData
go

exec sys.sp_set_session_context @key = N'username', @value = 'damauri', @read_only = 0;  
go

exec sys.sp_set_session_context @key = N'username', @value = 'jdoe', @read_only = 0;  
go
