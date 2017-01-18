drop table if exists Hacks, Announcements, Friends, ContestAuthor, 
					Submissions, ContestParticipation, ProblemsToContests, 
					Problems, Contests, Users;
drop type if exists Verdict, Division;
create type Verdict as enum ('OK', 'WA', 'RE', 'PE');
create type Division as enum ('div1', 'div2', 'all');

create table Contests (
	Id				serial primary key,
	Name			varchar(50) not null,
	IsRated			boolean not null,
	Div 			Division not null,
	StartTime		timestamp not null,
	Length			interval not null
);

create table Users (
	Id				serial primary key,
	Name			varchar(50) not null,
	Email			varchar(100) not null,
	Rating			int not null,
	Country			varchar(50)
);

create table Problems (
	Id				serial primary key,
	Name			varchar(50) not null,
	TimeLimit		real not null,
	MemoryLimit		int not null,
	ProblemText		varchar(500) not null,
	AuthorId		int not null,
	foreign key (AuthorId) references Users(Id) on delete cascade	
);

create table Announcements (
	Id              serial primary key,
	Message			varchar(300) not null,
	ContestId		int not null,
	foreign key (ContestId) references Contests(Id) on delete cascade
);

create table Friends (
	UserId			int,
	FriendId		int,
	primary key (UserId, FriendId),
	foreign key (UserId) references Users(Id) on delete cascade,	
	foreign key (FriendId) references Users(Id) on delete cascade
);

create table Submissions (
	SubmTime		timestamp,
	Result			Verdict not null,
	FailedOnTest	int,
	ProblemId		int,
	UserId			int,
	ContestId		int,
	primary key (SubmTime, ProblemId, UserId),
	foreign key (ContestId) references Contests(Id) on delete cascade,
	foreign key (UserId) references Users(Id) on delete cascade,	
	foreign key (ProblemId) references Problems(Id) on delete cascade,
	--задача либо сдана либо есть тест на котором она падает
	check (Result = 'OK'::Verdict or FailedOnTest is not null)
);

create table Hacks (
	HackTime		timestamp,
	Result			boolean not null,
	UserId			int,
	SubmDate		timestamp,
	SubmProblemId	int,
	SubmUserId		int,
	primary key (HackTime, UserId, SubmDate, SubmProblemId, SubmUserId),
	foreign key (UserId) references Users(Id) on delete cascade,	
	foreign key (SubmDate, SubmProblemId, SubmUserId) references Submissions(SubmTime, ProblemId, UserId) on delete cascade,	
	--пользователь не может взломать сам себя, взлом должен быть позже посылки
	check (UserId != SubmUserId and HackTime > SubmDate)
);

create table ProblemsToContests (
	ProblemNumber	char(1) not null,
	ContestId		int,
	ProblemId 		int,
	primary key (ContestId, ProblemId),
	foreign key (ContestId) references Contests(Id) on delete cascade,	
	foreign key (ProblemId) references Problems(Id) on delete cascade	
);

create table ContestAuthor (
	ContestId		int,
	UserId 			int,
	primary key (ContestId, UserId),
	foreign key (ContestId) references Contests(Id) on delete cascade,	
	foreign key (UserId) references Users(Id) on delete cascade	
);

create table ContestParticipation (
	ContestId		int,
	UserId 			int,
	primary key (ContestId, UserId),
	foreign key (ContestId) references Contests(Id) on delete cascade,	
	foreign key (UserId) references Users(Id) on delete cascade	
);

--triggers
-- посылки с контестом могут делать только зарегистрированные на соревнование пользователи
-- посылка с контестом должна быть сделано во время контеста
create or replace function checkSubmission() returns trigger language plpgsql as $$
declare 
	contest record;
begin
	if (new.ContestId is not null and 
		not exists (select * from ContestParticipation where UserId = new.UserId and ContestId = new.ContestId)) then
		raise exception 'unregistered users cant make submit';
	end if;
	if (new.ContestId is not null) then
		select * into contest from Contests where Id = new.ContestId;
		if (contest.StartTime > new.SubmTime or contest.StartTime + contest.Length < new.SubmTime) then 
			raise exception 'submits must be done in contest interval';
		end if;
	end if;
	return new;
end $$;
create trigger checkSubm before insert or update on Submissions for each row execute procedure checkSubmission();

-- взламыать можно только посылки с контестом
-- взламывать можно только во время контеста и только успешные посылки
create or replace function checkHack() returns trigger language plpgsql as $$
declare
	subm record;
	contest record;
begin
	select * into subm from Submissions where 
	(SubmTime = new.SubmDate and ProblemId = new.SubmProblemId and UserId = new.SubmUserId);
	if (subm.ContestId is null) then
		raise exception 'cant hack submits without contest';
	end if;
	if (subm.Result != 'OK'::Verdict) then
		raise exception 'cant hack not ok submits';
	end if;
	select * into contest from Contests where Id = subm.ContestId;
	if (contest.StartTime > new.HackTime or contest.StartTime + contest.Length < new.HackTime) then 
		raise exception 'submits can be hacked only during the contest';
	end if;
	return new;
end $$;
create trigger checkH before insert or update on Hacks for each row execute procedure checkHack();

--indices
create index Countries ON Users(Country);

--Insert test data
insert into Users (Name, Email, Rating, Country) values 
	('amir', 'amir@yandex.ru', 1950, 'Russia'),
	('ivan', 'ivan@gmail.com', 1700, 'Ukraine'),
	('vasya', 'author@gmail.com', 2000, 'Russia');
	
insert into Contests (Name, IsRated, Div, StartTime, Length) values 
	('First Contest', true, 'div1'::Division, '2017-01-10 19:30:00', '2h');

insert into Problems (Name, TimeLimit, MemoryLimit, ProblemText, AuthorId) values 
	('AplusB', 0.5, 256, 'print sum of a and b', 3),
	('AplusBplusC', 0.75, 256, 'print sum of a and b and c', 3);

insert into Friends (UserId, FriendId) values
	(1, 2),
	(1, 3);

insert into ContestParticipation (ContestId, UserId) values
	(1, 1),
	(1, 3);

insert into Submissions (SubmTime, Result, FailedOnTest, ProblemId, UserId, ContestId) values
	('2017-01-10 19:40:00', 'OK', null, 1, 3, 1),
	('2017-01-10 19:45:00', 'OK', null, 1, 3, 1),
	('2017-01-10 19:50:00', 'WA', 3, 2, 3, 1),
	('2017-01-10 19:55:00', 'WA', 3, 2, 1, 1);

insert into Hacks (HackTime, Result, UserId, SubmDate, SubmProblemId, SubmUserId) values
	('2017-01-10 19:42:00', true, 2, '2017-01-10 19:40:00', 1, 3);

insert into ProblemsToContests (ProblemNumber, ContestId, ProblemId) values
	('A', 1, 1),
	('B', 1, 2);

insert into ContestAuthor (ContestId, UserId) values
	(1, 3);

insert into Announcements (Message, ContestId) values
	('you should read A and B from standard input', 1);
