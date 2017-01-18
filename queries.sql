--1) все пользователи отсортированные по рейтингу	
select * from Users order by Rating desc;

--2) все друзья пользователя
drop function if exists getFriends(int);
create function getFriends(_UserId int) returns table(UId int, UName varchar(50)) as $$
	begin
		return query (select FriendId as UId, Name as UName from Friends inner join Users on Friends.FriendId = Users.Id
			where Friends.UserId = _UserId);
	end;
$$ language plpgsql;

--3) рейтинг самых популярных(у скольких человек данный пользователь в друзьях)
select Id, Name, coalesce(inFriends, 0) as inFriendList from Users left outer join 
	(select FriendId, count(*) as inFriends from Friends group by (FriendId)) as famous
	on FriendId = Id order by inFriendList desc;

--4) зарегистрировать пользователя на контест, false если нельзя зарегистрировать данного пользователя на контест
drop function if exists register(int, int);
create function register(_UserId int, _ContestId int) returns boolean as $$
	declare 
	rating int default
			(select Rating from Users where Id = _UserId);
	div Division default
			(select Div from Contests where Id = _ContestId);
	begin
		if (div = 'all'::Division or 
			(rating < 1900 and div = 'div2'::Division) or 
			(rating >= 1900 and div = 'div1'::Division)) then
			insert into ContestParticipation (ContestId, UserId) values (_ContestId, _UserId);
			return true;
		else
			return false; 
		end if;
	end;
$$ language plpgsql;

--5) пользователи, по количеству задач решенных на контесте
drop function if exists contestResult(int);
create function contestResult(_ContestId int) returns table(UId int, solved bigint) as $$
	begin
		return query select UserId as UId, (count(*) - 1) as solved from 
			(
			select distinct UserId, ProblemId from Submissions where Result = 'OK'::Verdict and	
			not exists (select * from Hacks where Submissions.SubmTime = Hacks.SubmDate and  
				Submissions.ProblemId = Hacks.SubmProblemId and Submissions.UserId = Hacks.SubmUserId) and 
			Submissions.ContestId is not null and 
			Submissions.ContestId = _ContestId  
			union 
			select distinct UserId, 0 as ProblemId from Submissions where 
			Submissions.ContestId is not null and Submissions.ContestId = _ContestId 
			) as allSolutions
		group by (UserId);
	end;
$$ language plpgsql;

--6) сколько зарегистрированных пользователей по странам
select Country, count(*) from Users group by (Country) order by count(*) desc;