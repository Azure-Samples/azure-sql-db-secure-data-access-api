if (user_id('MiddleTierUser') is null)  begin
	create user MiddleTierUser with password = 'a987REALLY#$%TRONGpa44w0rd';
	alter role db_owner add member MiddleTierUser;
end
go

drop security policy if exists rls.SensitiveDataPolicy;
drop function if exists rls.fn_SecurityPredicate;
drop table if exists rls.SensitiveDataPermissions;
drop table if exists dbo.EvenMoreSensitiveData;
drop table if exists dbo.SensitiveData;
drop procedure if exists web.get_sensitivedata
drop procedure if exists web.get_evenmoresensitivedata
go

drop schema if exists web;
go
create schema web;
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
    UserHashId bigint not null,
    SensitiveDataId int not null foreign key references dbo.SensitiveData(Id),
    HasAccess bit not null default(0),
    constraint pk__rls_SensitiveDataPermissions primary key nonclustered (UserHashId, SensitiveDataId)
)
go

create clustered index ixc on rls.SensitiveDataPermissions (SensitiveDataId)
go

insert into dbo.SensitiveData values
(1, 'Davide', 'Mauri', '{"SuperPowers":"Fly"}'),
(2, 'John', 'Doe', '{"SuperPowers":"Laser Eyes"}')
go

insert into dbo.EvenMoreSensitiveData values
(1, 1, 10, sysdatetime(), 'Some more secret info here'),
(2, 1, 20, sysdatetime(), 'and here'),
(3, 1, 30, sysdatetime(), 'and look, even here!'),
(4, 2, 100, sysdatetime(), 'Nothing to see here'),
(5, 2, 200, sysdatetime(), 'unless you look very close!')
go

insert into rls.SensitiveDataPermissions values
(-6134311, 1, 1),
(1225328053, 2, 1)
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
    (database_principal_id() = database_principal_id('MiddleTierUser') or is_member('db_owner') = 1)
and     
    UserHashId = cast(session_context(N'user-hash-id') as bigint)
and
    SensitiveDataId = @SensitiveDataId
go

create or alter procedure web.get_sensitivedata
as
select
    Id,
    FirstName,
    LastName,
    json_query(ReallyImportantData) as ReallyImportantData
from
    dbo.SensitiveData
for 
    json path
go

create or alter procedure web.get_evenmoresensitivedata
as
select
	s1.Id,
	s1.FirstName,
	s1.LastName,
    json_query(( 
        select 
            s2.Id, 
            s2.SomeData1,
            s2.SomeData2, 
            s2.SomeData3 
        from 
            dbo.[EvenMoreSensitiveData] s2 
        where 
            [s2].[SensitiveDataId] = [s1].[Id] 
        for 
            json auto
    )) as EvenMore
from
    dbo.SensitiveData s1
for
	json path
go

create security policy rls.SensitiveDataPolicy
add filter predicate rls.fn_SecurityPredicate(Id) on dbo.SensitiveData,
add filter predicate rls.fn_SecurityPredicate(SensitiveDataId) on dbo.EvenMoreSensitiveData
with (state = off);  

