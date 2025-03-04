
--
-- Test trigger
--
CREATE TABLE student(
	stu_id		int primary key,
	stu_name	varchar(40),
	age			int
);

CREATE TABLE score(
	stu_id		int,
	chinese_s	int,
	math_s		int,
	test_d		date
);

-- create tirgger function
CREATE OR REPLACE FUNCTION student_delete_trigger() 
  RETURN TRIGGER
AS
BEGIN
	DELETE FROM score WHERE stu_id = OLD.stu_id;
	RETURN OLD;
END;
/

-- create trigger
CREATE TRIGGER delete_student_trigger
	AFTER DELETE ON student
	FOR EACH ROW EXECUTE PROCEDURE student_delete_trigger();


INSERT INTO student VALUES(1, 'Jane', 14);
INSERT INTO student VALUES(2, 'Williams', 13);
INSERT INTO student VALUES(3, 'Tony', 15);

INSERT INTO score VALUES(1, 85, 75, to_date('23-05-2020', 'dd-mm-yyyy'));
INSERT INTO score VALUES(1, 80, 73, to_date('04-09-2020', 'dd-mm-yyyy'));
INSERT INTO score VALUES(2, 68, 83, to_date('23-05-2020', 'dd-mm-yyyy'));
INSERT INTO score VALUES(2, 73, 88, to_date('04-09-2020', 'dd-mm-yyyy'));
INSERT INTO score VALUES(3, 90, 79, to_date('23-05-2020', 'dd-mm-yyyy'));
INSERT INTO score VALUES(3, 86, 82, to_date('23-05-2020', 'dd-mm-yyyy'));

SELECT * FROM score;

-- delete student Tony from student table
DELETE FROM student WHERE stu_id = 3;

-- check score table
SELECT * FROM score;

-- clean up
drop trigger delete_student_trigger on student;
drop function student_delete_trigger;
drop table score;
delete from student;



--
-- statement-level trigger
--
CREATE TABLE log_student(
	update_time	date,
	db_user     varchar(40),
	opr_type	varchar(6)
);

CREATE OR REPLACE FUNCTION log_student_trigger()
  RETURN trigger 
AS
BEGIN
	INSERT INTO log_student VALUES(to_date('07-12-2020', 'dd-mm-yyyy'), 'postgres', TG_OP);
	RETURN NULL;
END;
/

CREATE TRIGGER log_student_trigger
	AFTER INSERT OR DELETE OR UPDATE ON student
	FOR STATEMENT EXECUTE PROCEDURE log_student_trigger();


INSERT INTO student VALUES(1, 'Mark', 14), (2, 'Wade', 14);

SELECT * FROM student;

SELECT * FROM log_student;

DELETE FROM log_student;
UPDATE student set age = 15;

SELECT * FROM log_student;

DELETE FROM log_student;
UPDATE student set age = 16 where stu_id = 3;
SELECT * FROM log_student;


drop trigger log_student_trigger on student;
delete from log_student;
delete from student;

--
-- row-level trigger
-- 
CREATE TRIGGER log_student_trigger2
	AFTER INSERT OR DELETE OR UPDATE ON student
	FOR ROW EXECUTE PROCEDURE log_student_trigger();

INSERT INTO student VALUES(1, 'Mark', 14), (2, 'Wade', 14);

SELECT * from log_student;

DELETE from log_student;

UPDATE student set age = 15;

SELECT * FROM log_student;

DELETE FROM log_student;
UPDATE student set age = 16 where stu_id = 3;

SELECT * FROM log_student;

drop trigger log_student_trigger2 on student;
drop function log_student_trigger;
drop table log_student;
drop table student;





--
-- Test recursion
--
CREATE OR REPLACE FUNCTION recursion_test(int,int) RETURN text 
AS
DECLARE
	rslt text;
BEGIN
    IF $1 <= 0 THEN
        rslt = CAST($2 AS TEXT);
    ELSE
        rslt = CAST($1 AS TEXT) || ',' || recursion_test($1 - 1, $2);
    END IF;
    RETURN rslt;
END;
/

SELECT recursion_test(4,3);
drop function recursion_test(int,int);

--
-- Test the FOUND magic variable
--
CREATE TABLE found_test_tbl (a int);

create or replace function test_found() return boolean 
as
begin
  insert into found_test_tbl values (1);
  if FOUND then
     insert into found_test_tbl values (2);
  end if;

  update found_test_tbl set a = 100 where a = 1;
  if FOUND then
    insert into found_test_tbl values (3);
  end if;

  delete from found_test_tbl where a = 9999; -- matches no rows
  if not FOUND then
    insert into found_test_tbl values (4);
  end if;

  return true;
end;
/

select test_found();
select * from found_test_tbl;
drop function test_found();

--
-- Test set-returning functions for PL/iSQL
--

create or replace function test_table_func_rec() return setof found_test_tbl as
	rec RECORD;
BEGIN
	FOR rec IN select * from found_test_tbl LOOP
		RETURN NEXT rec;
	END LOOP;
	RETURN;
END;
/

select * from test_table_func_rec();
drop function test_table_func_rec();


create or replace function test_table_func_row() return setof found_test_tbl as
DECLARE
	rown found_test_tbl%ROWTYPE;
BEGIN
	FOR rown IN select * from found_test_tbl LOOP
		RETURN NEXT rown;
	END LOOP;
	RETURN;
END;
/

select * from test_table_func_row();
drop function test_table_func_row();
drop table found_test_tbl;

create or replace function test_ret_set_scalar(int,int) return setof int as
DECLARE
	i int;
BEGIN
	FOR i IN $1 .. $2 LOOP
		RETURN NEXT i + 1;
	END LOOP;
	RETURN;
END;
/

select * from test_ret_set_scalar(1,10);
drop function test_ret_set_scalar;

create or replace function test_ret_set_rec_dyn(int) return setof record 
as
	retval RECORD;
BEGIN
	IF $1 > 10 THEN
		SELECT INTO retval 5, 10, 15;
		RETURN NEXT retval;
		RETURN NEXT retval;
	ELSE
		SELECT INTO retval 50, 5::numeric, 'xxx'::text;
		RETURN NEXT retval;
		RETURN NEXT retval;
	END IF;
	RETURN;
END;
/

SELECT * FROM test_ret_set_rec_dyn(1500) AS (a int, b int, c int);
SELECT * FROM test_ret_set_rec_dyn(5) AS (a int, b numeric, c text);

drop function test_ret_set_rec_dyn;

create function test_ret_rec_dyn(int) return record
as 
DECLARE
	retval RECORD;
BEGIN
	IF $1 > 10 THEN
		SELECT INTO retval 5, 10, 15;
		RETURN retval;
	ELSE
		SELECT INTO retval 50, 5::numeric, 'xxx'::text;
		RETURN retval;
	END IF;
END;
/

SELECT * FROM test_ret_rec_dyn(1500) AS (a int, b int, c int);
SELECT * FROM test_ret_rec_dyn(5) AS (a int, b numeric, c text);

drop function test_ret_rec_dyn;

--
-- Test handling of OUT parameters
--
create or replace function f1(in i int, out j int) return setof int as
begin
  j := i+1;
  return next;
  j := i+2;
  return next;
  return;
end;
/

select * from f1(42);
drop function f1;

create or replace function f1(in i int, out j int, out k text) returns setof record 
as $$
begin
  j := i+1;
  k := 'foo';
  return next;
  j := j+1;
  k := 'foot';
  return next;
end$$ language plisql;

select * from f1(42);
drop function f1;

create or replace function duplic(in i anyelement, out j anyelement, out k anyarray) 
as $$
begin
  j := i;
  k := array[j,j];
  return;
end$$ language plisql;

select * from duplic(42);
select * from duplic('foo'::text);
drop function duplic;


--
-- test PERFORM
--
create table perform_test (
	a	INT,
	b	INT
);

create or replace function perform_simple_func(int) return boolean as 
BEGIN
	IF $1 < 20 THEN
		INSERT INTO perform_test VALUES ($1, $1 + 10);
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;
/

create or replace function perform_test_func() return void as
BEGIN
	IF FOUND then
		INSERT INTO perform_test VALUES (100, 100);
	END IF;

	PERFORM perform_simple_func(5);

	IF FOUND then
		INSERT INTO perform_test VALUES (100, 100);
	END IF;

	PERFORM perform_simple_func(50);

	IF FOUND then
		INSERT INTO perform_test VALUES (100, 100);
	END IF;

	RETURN;
END;
/

SELECT perform_test_func();
SELECT * FROM perform_test;

drop function perform_test_func;
drop function perform_simple_func;
drop table perform_test;

--
-- Test proper snapshot handling in simple expressions
--

create temp table users(login text, id serial);

create or replace function sp_id_user(a_login text) return int 
as
	x int;
begin
  select into x id from users where login = a_login;
  if found then return x; end if;
  return 0;
end;
/

insert into users values('user1');

select sp_id_user('user1');
select sp_id_user('userx');

create or replace function sp_add_user(a_login text) return int 
as
	my_id_user int;
begin
  my_id_user = sp_id_user( a_login );
  IF  my_id_user > 0 THEN
    RETURN -1;  -- error code for existing user
  END IF;
  INSERT INTO users ( login ) VALUES ( a_login );
  my_id_user = sp_id_user( a_login );
  IF  my_id_user = 0 THEN
    RETURN -2;  -- error code for insertion failure
  END IF;
  RETURN my_id_user;
end;
/

select sp_add_user('user1');
select sp_add_user('user2');
select sp_add_user('user2');
select sp_add_user('user3');
select sp_add_user('user3');

drop function sp_add_user(text);
drop function sp_id_user(text);

--
-- tests for refcursors
--
drop table if exists rc_test;
create table rc_test (a int, b int);
copy rc_test from stdin;
5	10
50	100
500	1000
\.

create or replace function return_unnamed_refcursor() return refcursor 
as
    rc refcursor;
begin
    open rc for select a from rc_test;
    return rc;
end;
/

create or replace function use_refcursor(rc refcursor) return int 
as
declare
    x record;
begin
    rc := return_unnamed_refcursor();
    fetch next from rc into x;
    return x.a;
end;
/

select use_refcursor(return_unnamed_refcursor());

create or replace function return_refcursor(rc refcursor) return refcursor 
as 
begin
    open rc for select a from rc_test;
    return rc;
end;
/

create or replace function refcursor_test1(refcursor) returns refcursor
as $$
begin
    perform return_refcursor($1);
    return $1;
end;
$$ language plisql;

begin;

select refcursor_test1('test1');
fetch next in test1;

select refcursor_test1('test2');
fetch all from test2;

commit;

-- should fail
fetch next from test1;

create or replace function refcursor_test2(int, int) return boolean 
as
    cursor c1(param1 int, param2 int) for select * from rc_test where a > param1 and b > param2;
    nonsense record;
begin
    open c1($1, $2);
    fetch c1 into nonsense;
    close c1;
    if found then
        return true;
    else
        return false;
    end if;
end;
/

select refcursor_test2(20000, 20000) as "Should be false",
       refcursor_test2(20, 20) as "Should be true";

--
-- tests for cursors with named parameter arguments
--
create or replace function namedparmcursor_test1(int, int) return boolean 
as
    cursor c1(param1 int, param12 int) for select * from rc_test where a > param1 and b > param12;
    nonsense record;
begin
    open c1(param12 := $2, param1 := $1);
    fetch c1 into nonsense;
    close c1;
    if found then
        return true;
    else
        return false;
    end if;
end;
/

select namedparmcursor_test1(20000, 20000) as "Should be false",
       namedparmcursor_test1(20, 20) as "Should be true";

-- mixing named and positional argument notations
create or replace function namedparmcursor_test2(int, int) return boolean 
as 
	cursor c1(param1 int, param2 int) for select * from rc_test where a > param1 and b > param2;
	nonsense record;
begin
	open c1(param1 := $1, $2);
	fetch c1 into nonsense;
	close c1;
	if found then
		return true;
	else
		return false;
	end if;
end;
/

select namedparmcursor_test2(20, 20);
drop function refcursor_test1;
drop function refcursor_test2;
drop function return_refcursor;
drop function use_refcursor;
drop function return_unnamed_refcursor;
drop function namedparmcursor_test1;
drop function namedparmcursor_test2;
drop table rc_test;

--
-- Test cursor with return clause
--
CREATE TABLE emp (    
	empno           INTEGER NOT NULL,    
	ename           VARCHAR(10),    
	job             VARCHAR(9),    
	mgr             NUMERIC(4),    
	hiredate        DATE,    
	sal             NUMERIC(7,2) ,    
	comm            NUMERIC(7,2),    
	deptno          NUMERIC(2) 
);

INSERT INTO emp VALUES(736,'SMITH','CLERK',7902,to_date('17-12-2018','dd-mm-yyyy'),800,NULL,20);
INSERT INTO emp VALUES(749,'ALLEN','SALESMAN',7698,to_date('20-2-2018','dd-mm-yyyy'),1600,300,30);

-- Test support Column Alias In Cursor
create or replace function test_cur1(x int) return int
as
   cursor emp_cur(x int)
   is
    select empno, (sal+1000) salary from emp where empno = x; 
  	emp_rec emp_cur%rowtype;
begin
	open emp_cur(x); 
	fetch emp_cur into emp_rec;
	raise notice 'empno = %,salary = %', emp_rec.empno, emp_rec.salary;
	close emp_cur;
	return 0;
end;
/

select test_cur1(736);
drop function test_cur1;

--
-- support define a cursor contains the return clause.
--
create or replace function test_cur2() return int
as
    cursor c2 return emp%rowtype
    is
      select * from emp where empno = 736;
    emp_rec c2%rowtype;
begin
    open c2;
    fetch c2 into emp_rec;
    raise notice 'emp_id = %, emp_name = %, salary = %',emp_rec.empno,emp_rec.ename,emp_rec.sal;
	close c2;
	return 0;
end;
/

select test_cur2();
drop function test_cur2;

--
-- support define a cursor variable contains the return clause
--
create or replace function test_cur3() return int
as
    CURSOR c1 RETURN emp%rowtype;
    emp_rec c1%rowtype;  
begin
    open c1 for select * from emp where empno = 736;
    fetch c1 into emp_rec;
    raise notice 'emp_id = %, emp_name = %, emp_salary = %', emp_rec.empno, emp_rec.ename, emp_rec.sal;
    close c1;
    return 0;
end;
/

select test_cur3();
drop function test_cur3;

--
-- test cursor default parameter
--
create or replace procedure test_cur4()
is  
	cursor emp_cur(emp_id_in int := 736)  
	is select * from emp where empno = emp_id_in;  
	emp_rec emp_cur%rowtype; 
begin	
	open emp_cur(emp_id_in);	
	fetch emp_cur into emp_rec;	
	raise notice 'empno = %, ename = %, sal = %', emp_rec.empno, emp_rec.ename, emp_rec.sal;	
	close emp_cur;
end;
/

call test_cur4();

-- test Do structure for CALL
begin
	call test_cur4();
end;
/

drop procedure test_cur4();
drop table emp;

--
-- EXECUTE ... INTO test
--
create table eifoo (i integer, y integer);
--create type eitype as (i integer, y integer);

create or replace function execute_into_test(varchar) return record 
as
	type eitype is record(m int, n int);
    _r record;
    _rt eifoo%rowtype;
    _v eitype;
    i int;
    j int;
    k int;
begin
    execute 'insert into '||$1||' values(10,15)';
    execute 'select (row).* from (select row(10,1)::eifoo) s' into _r;
    raise notice '% %', _r.i, _r.y;
    execute 'select * from '||$1||' limit 1' into _rt;
    raise notice '% %', _rt.i, _rt.y;
    execute 'select *, 20 from '||$1||' limit 1' into i, j, k;
    raise notice '% % %', i, j, k;
    execute 'select 1,2' into _v;
    return _v;
end; 
/

select execute_into_test('eifoo');

drop function execute_into_test;
drop table eifoo;

-- parameters of raise stmt can be expressions
create or replace function raise_exprs() return void as
declare
    a integer[] = '{10,20,30}';
    c varchar = 'xyz';
    i integer;
begin
    i := 2;
    raise notice '%; %; %; %; %; %', a, a[i], c, (select c || 'abc'), row(10,'aaa',NULL,30), NULL;
end;
/

select raise_exprs();
drop function raise_exprs();

CREATE FUNCTION reraise_test() RETURNS void 
AS $$
BEGIN   
  BEGIN       
    RAISE syntax_error;   
  EXCEPTION       
  	WHEN syntax_error THEN           
  	  BEGIN               
  	    raise notice 'exception % thrown in inner block, reraising', sqlerrm;               
        RAISE;           
	  EXCEPTION               
	  	WHEN OTHERS THEN                   
	  	  raise notice 'RIGHT - exception % caught in inner block', sqlerrm;          
	  END;   
  END;
EXCEPTION   
  WHEN OTHERS THEN       
    raise notice 'WRONG - exception % caught in outer block', sqlerrm;
END;
$$ LANGUAGE plisql;

select reraise_test();
drop function reraise_test();

--
-- Test STRICT limiter in both planned and EXECUTE invocations.
-- Note that a data-modifying query is quasi strict (disallow multi rows)
-- by default in the planned case, but not in EXECUTE.
--

create temp table foo (f1 int, f2 int);

insert into foo values (1,2), (3,4);

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should work
  insert into foo values(5,6) returning * into x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should fail due to implicit strict
  insert into foo values(7,8),(9,10) returning * into x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should work
  execute 'insert into foo values(5,6) returning *' into x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- this should work since EXECUTE isn't as picky
  execute 'insert into foo values(7,8),(9,10) returning *' into x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

select * from foo;

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should work
  select * from foo where f1 = 3 into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();


create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should fail, no rows
  select * from foo where f1 = 0 into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();


create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should fail, too many rows
  select * from foo where f1 > 3 into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should work
  execute 'select * from foo where f1 = 3' into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should fail, no rows
  execute 'select * from foo where f1 = 0' into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

create or replace function stricttest() return void as
declare 
	x record;
begin
  -- should fail, too many rows
  execute 'select * from foo where f1 > 3' into strict x;
  raise notice 'x.f1 = %, x.f2 = %', x.f1, x.f2;
end;
/

select stricttest();

drop function stricttest();


-- test warnings and errors
set plisql.extra_warnings to 'all';
set plisql.extra_warnings to 'none';
set plisql.extra_errors to 'all';
set plisql.extra_errors to 'none';

-- test warnings when shadowing a variable

set plisql.extra_warnings to 'shadowed_variables';

-- simple shadowing of vars between blocks
create or replace function shadowtest()
	returns table (x int) as $$
declare --block 1
  in1 int;
  out1 int;
begin
  declare --block 2
    in1 int;
    out1 int;
  begin
  end;
end
$$ language plisql;

select shadowtest();
drop function shadowtest();

-- duplicate var declaration with function parameter
create or replace function shadowtest(in1 int)
	returns table (out1 int) as $$
declare
in1 int;
out1 int;
begin
end
$$ language plisql;



-- shadowing in a second DECLARE block
create or replace function shadowtest()
	returns void as $$
declare
f1 int;
begin
	declare
	f1 int;
	begin
	end;
end$$ language plisql;

drop function shadowtest();

-- several levels of shadowing
create or replace function shadowtest(in1 int)
	returns void as $$
declare
in1 int;
begin
	declare
	in1 int;
	begin
	end;
end$$ language plisql;


-- shadowing in cursor definitions
create or replace function shadowtest()
	returns void as $$
declare
	f1 int;
	cursor c1(f1 int) for select 1;
begin
end$$ language plisql;
drop function shadowtest();

-- test errors when shadowing a variable

set plisql.extra_errors to 'shadowed_variables';

create or replace function shadowtest(f1 int)
	returns boolean as $$
declare f1 int; begin return 1; end $$ language plisql;


reset plisql.extra_errors;
reset plisql.extra_warnings;

create or replace function shadowtest(f1 int)
	returns boolean as $$
declare f1 int; begin return 1; end $$ language plisql;



-- runtime extra checks
set plisql.extra_warnings to 'too_many_rows';

declare x int;
begin
  select v from generate_series(1,2) g(v) into x;
end;
/

set plisql.extra_errors to 'too_many_rows';

declare x int;
begin
  select v from generate_series(1,2) g(v) into x;
end;
/

reset plisql.extra_errors;
reset plisql.extra_warnings;


set plisql.extra_warnings to 'strict_multi_assignment';

declare
  x int;
  y int;
begin
  select 1 into x, y;
  select 1,2 into x, y;
  select 1,2,3 into x, y;
end;
/

set plisql.extra_errors to 'strict_multi_assignment';

declare
  x int;
  y int;
begin
  select 1 into x, y;
  select 1,2 into x, y;
  select 1,2,3 into x, y;
end;
/

create table test_01(a int, b int, c int);

alter table test_01 drop column a;

-- the check is active only when source table is not empty
insert into test_01 values(10,20);

declare
  x int;
  y int;
begin
  select * from test_01 into x, y; -- should be ok
  raise notice 'ok';
  select * from test_01 into x;    -- should to fail
end;
/


declare
  t test_01;
begin
  select 1, 2 into t;  -- should be ok
  raise notice 'ok';
  select 1, 2, 3 into t; -- should fail;
end;
/

declare
  t test_01;
begin
  select 1 into t; -- should fail;
end;
/

drop table test_01;

reset plisql.extra_errors;
reset plisql.extra_warnings;


-- test scrollable cursor support
create table tcur_tb(f1 int);
insert into tcur_tb values (1),(2),(3);

create function sc_test() return setof integer as
declare
  cursor c scroll for select f1 from tcur_tb;
  x integer;
begin
  open c;
  fetch last from c into x;
  while found loop
    return next x;
    fetch prior from c into x;
  end loop;
  close c;
end;
/

select * from sc_test();


create or replace function sc_test() return setof integer as
declare
  cursor c no scroll for select f1 from tcur_tb;
  x integer;
begin
  open c;
  fetch last from c into x;
  while found loop
    return next x;
    fetch prior from c into x;
  end loop;
  close c;
end;
/

select * from sc_test();  -- fails because of NO SCROLL specification

create or replace function sc_test() return setof integer as
declare
  c refcursor;
  x integer;
begin
  open c scroll for select f1 from tcur_tb;
  fetch last from c into x;
  while found loop
    return next x;
    fetch prior from c into x;
  end loop;
  close c;
end;
/

select * from sc_test();


create or replace function sc_test() return setof integer as
declare
  c refcursor;
  x integer;
begin
  open c scroll for execute 'select f1 from tcur_tb';
  fetch last from c into x;
  while found loop
    return next x;
    fetch relative -2 from c into x;
  end loop;
  close c;
end;
/

select * from sc_test();

create or replace function sc_test() return setof integer as
declare
  c refcursor;
  x integer;
begin
  open c scroll for execute 'select f1 from tcur_tb';
  fetch last from c into x;
  while found loop
    return next x;
    move backward 2 from c;
    fetch relative -1 from c into x;
  end loop;
  close c;
end;
/

select * from sc_test();

create or replace function sc_test() return setof integer as
declare
  cursor c for select * from generate_series(1, 10);
  x integer;
begin
  open c;
  loop
      move relative 2 in c;
      if not found then
          exit;
      end if;
      fetch next from c into x;
      if found then
          return next x;
      end if;
  end loop;
  close c;
end;
/

select * from sc_test();

create or replace function sc_test() return setof integer as
declare
  cursor c for select * from generate_series(1, 10);
  x integer;
begin
  open c;
  move forward all in c;
  fetch backward from c into x;
  if found then
    return next x;
  end if;
  close c;
end;
/

select * from sc_test();

drop function sc_test();
drop table tcur_tb;


-- test qualified variable names

create or replace function pl_qual_names (param1 int) return void as
declare
  param2 int := 1;
begin
  <<innerblock>>
  declare
    param1 int := 2;
  begin
    raise notice 'param1 = %', param1;
    raise notice 'pl_qual_names.param1 = %', pl_qual_names.param1;
    raise notice 'pl_qual_names.param2 = %', pl_qual_names.param2;
    raise notice 'innerblock.param1 = %', innerblock.param1;
  end;
end;
/

select pl_qual_names(42);

drop function pl_qual_names(int);


-- tests for RETURN QUERY

create type record_type as (x text, y int, z boolean);

create or replace function ret_query2(lim int) return setof record_type as
begin
    return query select md5(s.x::text), s.x, s.x > 0
                 from generate_series(-8, lim) s (x) where s.x % 2 = 0;
end;
/

select * from ret_query2(8);

drop function ret_query2;
drop type record_type;


-- test EXECUTE USING
create function exc_using(int, text) return int as
declare i int;
begin
  for i in execute 'select * from generate_series(1,$1)' using $1+1 loop
    raise notice '%', i;
  end loop;
  execute 'select $2 + $2*3 + length($1)' into i using $2,$1;
  return i;
end;
/

select exc_using(5, 'foobar');

drop function exc_using(int, text);


create or replace function exc_using(int) return void as
declare
  c refcursor;
  i int;
begin
  open c for execute 'select * from generate_series(1,$1)' using $1+1;
  loop
    fetch c into i;
    exit when not found;
    raise notice '%', i;
  end loop;
  close c;
  return;
end;
/

select exc_using(5);

drop function exc_using(int);

-- test FOR-over-cursor

create or replace function forc01() return void as
declare
  cursor c(r1 integer, r2 integer)
       for select * from generate_series(r1,r2) i;
  cursor c2
       for select * from generate_series(41,43) i;
begin
  for r in c(5,7) loop
    raise notice '% from %', r.i, c;
  end loop;
  -- again, to test if cursor was closed properly
  for r in c(9,10) loop
    raise notice '% from %', r.i, c;
  end loop;
  -- and test a parameterless cursor
  for r in c2 loop
    raise notice '% from %', r.i, c2;
  end loop;
  -- and try it with a hand-assigned name
  raise notice 'after loop, c2 = %', c2;
  c2 := 'special_name';
  for r in c2 loop
    raise notice '% from %', r.i, c2;
  end loop;
  raise notice 'after loop, c2 = %', c2;
  -- and try it with a generated name
  -- (which we can't show in the output because it's variable)
  c2 := null;
  for r in c2 loop
    raise notice '%', r.i;
  end loop;
  raise notice 'after loop, c2 = %', c2;
  return;
end;
/

select forc01();


-- try updating the cursor's current row

create temp table forc_test as
  select n as i, n as j from generate_series(1,10) n;

create or replace function forc01() return void as
declare
  cursor c for select * from forc_test;
begin
  for r in c loop
    raise notice '%, %', r.i, r.j;
    update forc_test set i = i * 100, j = r.j * 2 where current of c;
  end loop;
end;
/

select forc01();

select * from forc_test;
drop function forc01();


-- fail because cursor has no query bound to it

create or replace function forc_bad() return void as
declare
  c refcursor;
begin
  for r in c loop
    raise notice '%', r.i;
  end loop;
end;
/


-- test RETURN QUERY EXECUTE

create or replace function return_dquery() return setof int as
begin
  return query execute 'select * from (values(10),(20)) f';
  return query execute 'select * from (values($1),($2)) f' using 40,50;
end;
/

select return_dquery();

drop function return_dquery();


-- test RETURN QUERY with dropped columns

create table tabwithcols(a int, b int, c int, d int);
insert into tabwithcols values(10,20,30,40),(50,60,70,80);

create or replace function returnqueryf()
return setof tabwithcols as
begin
  return query select * from tabwithcols;
  return query execute 'select * from tabwithcols';
end;
/

select * from returnqueryf();

alter table tabwithcols drop column b;

select * from returnqueryf();

alter table tabwithcols drop column d;

select * from returnqueryf();

alter table tabwithcols add column d int;

select * from returnqueryf();

drop function returnqueryf();
drop table tabwithcols;


--
-- Tests for composite-type results
--

create type compostype as (x int, y varchar);

-- test: use of variable of composite type in return statement
create or replace function compos() return compostype as
declare
  v compostype;
begin
  v := (1, 'hello');
  return v;
end;
/

select compos();

-- test: use of variable of record type in return statement
create or replace function compos() return compostype as
declare
  v record;
begin
  v := (1, 'hello'::varchar);
  return v;
end;
/

select compos();

-- test: use of row expr in return statement
create or replace function compos() return compostype as
begin
  return (1, 'hello'::varchar);
end;
/

select compos();

-- this does not work currently (no implicit casting)
create or replace function compos() return compostype as
begin
  return (1, 'hello');
end;
/

select compos();

-- ... but this does
create or replace function compos() return compostype as
begin
  return (1, 'hello')::compostype;
end;
/

select compos();

drop function compos();


-- test: return a row expr as record.
create or replace function composrec() return record as
declare
  v record;
begin
  v := (1, 'hello');
  return v;
end;
/

select composrec();

-- test: return row expr in return statement.
create or replace function composrec() return record as
begin
  return (1, 'hello');
end;
/

select composrec();

drop function composrec();


-- test: the parameter is record
create or replace function tfunc(r record) return int
as
begin
	r := (1, 'hello')::record;
	return 1;
end;
/

select tfunc((1,'hello')::record);
drop function tfunc(record);


-- test: row expr in RETURN NEXT statement.
create or replace function compos() return setof compostype as
begin
  for i in 1..3
  loop
    return next (1, 'hello'::varchar);
  end loop;
  return next null::compostype;
  return next (2, 'goodbye')::compostype;
end;
/

select * from compos();

drop function compos();

-- test: use invalid expr in return statement.
create or replace function compos() return compostype as
begin
  return 1 + 1;
end;
/

select compos();

-- RETURN variable is a different code path ...
create or replace function compos() return compostype as
declare 
	x int := 42;
begin
  return x;
end;
/

select * from compos();

drop function compos();

-- test: invalid use of composite variable in scalar-returning function
create or replace function compos() return int as
declare
  v compostype;
begin
  v := (1, 'hello');
  return v;
end;
/

select compos();

-- test: invalid use of composite expression in scalar-returning function
create or replace function compos() return int as
begin
  return (1, 'hello')::compostype;
end;
/

select compos();

drop function compos();
drop type compostype;


--
-- Tests for 8.4's new RAISE features
--

create or replace function raise_test() returns void as $$
begin
  raise notice '% % %', 1, 2, 3
     using errcode = '55001', detail = 'some detail info', hint = 'some hint';
  raise '% % %', 1, 2, 3
     using errcode = 'division_by_zero', detail = 'some detail info';
end;
$$ language plisql;

select raise_test();


-- Since we can't actually see the thrown SQLSTATE in default psql output,
-- test it like this; this also tests re-RAISE

create or replace function raise_test() returns void as $$
begin
  raise 'check me'
     using errcode = 'division_by_zero', detail = 'some detail info';
  exception
    when others then
      raise notice 'SQLSTATE: % SQLERRM: %', sqlstate, sqlerrm;
      raise;
end;
$$ language plisql;

select raise_test();


create or replace function raise_test() returns void as $$
begin
  raise 'check me'
     using errcode = '1234F', detail = 'some detail info';
  exception
    when others then
      raise notice 'SQLSTATE: % SQLERRM: %', sqlstate, sqlerrm;
      raise;
end;
$$ language plisql;

select raise_test();

-- SQLSTATE specification in WHEN
create or replace function raise_test() returns void as $$
begin
  raise 'check me'
     using errcode = '1234F', detail = 'some detail info';
  exception
    when sqlstate '1234F' then
      raise notice 'SQLSTATE: % SQLERRM: %', sqlstate, sqlerrm;
      raise;
end;
$$ language plisql;

select raise_test();

create or replace function raise_test() returns void as $$
begin
  raise division_by_zero using detail = 'some detail info';
  exception
    when others then
      raise notice 'SQLSTATE: % SQLERRM: %', sqlstate, sqlerrm;
      raise;
end;
$$ language plisql;

select raise_test();

create or replace function raise_test() returns void as $$
begin
  raise division_by_zero;
end;
$$ language plisql;

select raise_test();

create or replace function raise_test() returns void as $$
begin
  raise sqlstate '1234F';
end;
$$ language plisql;

select raise_test();

create or replace function raise_test() returns void as $$
begin
  raise division_by_zero using message = 'custom' || ' message';
end;
$$ language plisql;

select raise_test();

create or replace function raise_test() returns void as $$
begin
  raise using message = 'custom' || ' message', errcode = '22012';
end;
$$ language plisql;

select raise_test();

-- conflict on message
create or replace function raise_test() returns void as $$
begin
  raise notice 'some message' using message = 'custom' || ' message', errcode = '22012';
end;
$$ language plisql;

select raise_test();

-- conflict on errcode
create or replace function raise_test() returns void as $$
begin
  raise division_by_zero using message = 'custom' || ' message', errcode = '22012';
end;
$$ language plisql;

select raise_test();

-- nothing to re-RAISE
create or replace function raise_test() returns void as $$
begin
  raise;
end;
$$ language plisql;

select raise_test();


-- test access to exception data
create or replace function zero_divide() returns int as $$
declare 
	v int := 0;
begin
  return 10 / v;
end;
$$ language plisql;

create function stacked_diagnostics_test() returns void as $$
declare _sqlstate text;
        _message text;
        _context text;
begin
  perform zero_divide();
exception when others then
  get stacked diagnostics
        _sqlstate = returned_sqlstate,
        _message = message_text,
        _context = pg_exception_context;
  raise notice 'sqlstate: %, message: %, context: [%]',
    _sqlstate, _message, replace(_context, E'\n', ' <- ');
end;
$$ language plisql;

select stacked_diagnostics_test();

create or replace function stacked_diagnostics_test() returns void as $$
declare _detail text;
        _hint text;
        _message text;
begin
  perform raise_test();
exception when others then
  get stacked diagnostics
        _message = message_text,
        _detail = pg_exception_detail,
        _hint = pg_exception_hint;
  raise notice 'message: %, detail: %, hint: %', _message, _detail, _hint;
end;
$$ language plisql;

select stacked_diagnostics_test();

-- fail, cannot use stacked diagnostics statement outside handler
create or replace function stacked_diagnostics_test() returns void as $$
declare _detail text;
        _hint text;
        _message text;
begin
  get stacked diagnostics
        _message = message_text,
        _detail = pg_exception_detail,
        _hint = pg_exception_hint;
  raise notice 'message: %, detail: %, hint: %', _message, _detail, _hint;
end;
$$ language plisql;


-- test passing column_name, constraint_name, datatype_name, table_name
-- and schema_name error fields

create or replace function stacked_diagnostics_test() returns void as $$
declare _column_name text;
        _constraint_name text;
        _datatype_name text;
        _table_name text;
        _schema_name text;
begin
  raise exception using
    column = '>>some column name<<',
    constraint = '>>some constraint name<<',
    datatype = '>>some datatype name<<',
    table = '>>some table name<<',
    schema = '>>some schema name<<';
exception when others then
  get stacked diagnostics
        _column_name = column_name,
        _constraint_name = constraint_name,
        _datatype_name = pg_datatype_name,
        _table_name = table_name,
        _schema_name = schema_name;
  raise notice 'column %, constraint %, type %, table %, schema %',
    _column_name, _constraint_name, _datatype_name, _table_name, _schema_name;
end;
$$ language plisql;

select stacked_diagnostics_test();
drop function zero_divide();
drop function stacked_diagnostics_test();
drop function raise_test();


-- test variadic functions

create or replace function vari(variadic int[]) return void as
begin
  for i in array_lower($1,1)..array_upper($1,1) loop
    raise notice '%', $1[i];
  end loop; end;
/

select vari(1,2,3,4,5);
select vari(3,4,5);
select vari(variadic array[5,6,7]);

drop function vari(int[]);


-- coercion test
create or replace function pleast(variadic numeric[])
returns numeric as $$
declare 
  aux numeric = $1[array_lower($1,1)];
begin
  for i in array_lower($1,1)+1..array_upper($1,1) loop
    if $1[i] < aux then aux := $1[i]; end if;
  end loop;
  return aux;
end;
$$ language plisql immutable strict;

select pleast(10,1,2,3,-16);
select pleast(10.2,2.2,-1.1);
select pleast(10.2,10, -20);
select pleast(10,20, -1.0);

-- in case of conflict, non-variadic version is preferred
create or replace function pleast(numeric)
returns numeric as $$
begin
  raise notice 'non-variadic function called';
  return $1;
end;
$$ language plisql immutable strict;

select pleast(10);

drop function pleast(numeric[]);
drop function pleast(numeric);


-- test table functions

create or replace function tftest(int) returns table(a int, b int) as $$
begin
  return query select $1, $1+i from generate_series(1,5) g(i);
end;
$$ language plisql immutable strict;


select * from tftest(10);

create or replace function tftest(a1 int) returns table(a int, b int) as $$
begin
  a := a1; b := a1 + 1;
  return next;
  a := a1 * 10; b := a1 * 10 + 1;
  return next;
end;
$$ language plisql immutable strict;


select * from tftest(10);

drop function tftest(int);


create or replace function rttest() returns setof int as $$
declare 
  rc int;
begin
  return query values(10),(20);
  get diagnostics rc = row_count;
  raise notice '% %', found, rc;
  return query select * from (values(10),(20)) f(a) where false;
  get diagnostics rc = row_count;
  raise notice '% %', found, rc;
  return query execute 'values(10),(20)';
  get diagnostics rc = row_count;
  raise notice '% %', found, rc;
  return query execute 'select * from (values(10),(20)) f(a) where false';
  get diagnostics rc = row_count;
  raise notice '% %', found, rc;
end;
$$ language plisql;

select * from rttest();

drop function rttest();


-- Test for proper cleanup at subtransaction exit.  This example
-- exposed a bug in PG 8.2.

CREATE OR REPLACE FUNCTION leaker_2(fail BOOL, OUT error_code INTEGER, OUT new_id INTEGER)
  RETURNS RECORD AS $$
BEGIN
  IF fail THEN
    RAISE EXCEPTION 'fail ...';
  END IF;
  error_code := 1;
  new_id := 1;
  RETURN;
END;
$$ LANGUAGE plisql;


SELECT * FROM leaker_2(false);
SELECT * FROM leaker_2(true);

DROP FUNCTION leaker_2(bool);


-- Test for appropriate cleanup of non-simple expression evaluations
-- (bug in all versions prior to August 2010)

CREATE OR REPLACE FUNCTION nonsimple_expr_test() RETURN text[] AS
DECLARE
  arr text[];
  lr text;
  i integer;
BEGIN
  arr := array[array['foo','bar'], array['baz', 'quux']];
  lr := 'fool';
  i := 1;
  -- use sub-SELECTs to make expressions non-simple
  arr[(SELECT i)][(SELECT i+1)] := (SELECT lr);
  RETURN arr;
END;
/

SELECT nonsimple_expr_test();

DROP FUNCTION nonsimple_expr_test();


create or replace function error1(text) returns text language sql as
$$ SELECT relname::text FROM pg_class c WHERE c.oid = $1::regclass $$;

create or replace function error2(p_name_table text) returns text
as $$
begin
  return error1(p_name_table);
end;
$$ language plisql;

BEGIN;
create table public.stuffs (stuff text);
SAVEPOINT a;
select error2('nonexistent.stuffs');
ROLLBACK TO a;
select error2('public.stuffs');
rollback;

drop function error2(p_name_table text);
drop function error1(text);


-- Test for proper handling of cast-expression caching

create function sql_to_date(integer) returns date as $$
select $1::text::date
$$ language sql immutable strict;

create cast (integer as date) with function sql_to_date(integer) as assignment;

create function cast_invoker(integer) returns date as $$
begin
  return $1;
end$$ language plisql;

select cast_invoker(20150717);
select cast_invoker(20150718);  -- second call crashed in pre-release 9.5

begin;
select cast_invoker(20150717);
select cast_invoker(20150718);
savepoint s1;
select cast_invoker(20150718);
select cast_invoker(-1); -- fails
rollback to savepoint s1;
select cast_invoker(20150719);
select cast_invoker(20150720);
commit;

drop function cast_invoker(integer);
drop function sql_to_date(integer) cascade;


-- Test handling of cast cache inside DO blocks
-- (to check the original crash case, this must be a cast not previously
-- used in this session)

begin;
declare x text[]; begin x := '{1.23, 4.56}'::numeric[]; end;
/
declare x text[]; begin x := '{1.23, 4.56}'::numeric[]; end;
/
end;

-- Test for consistent reporting of error context

create or replace function fail() return int as
begin
  return 1/0;
end;
/

select fail();
select fail();

drop function fail();


-- Test handling of string literals.

set standard_conforming_strings = off;

create or replace function strtest() return text as
begin
  raise notice 'foo\\bar\041baz';
  return 'foo\\bar\041baz';
end;
/


select strtest();

create or replace function strtest() return text as
begin
  raise notice E'foo\\bar\041baz';
  return E'foo\\bar\041baz';
end;
/

select strtest();

set standard_conforming_strings = on;

create or replace function strtest() return text as
begin
  raise notice 'foo\\bar\041baz\';
  return 'foo\\bar\041baz\';
end;
/

select strtest();

create or replace function strtest() return text as
begin
  raise notice E'foo\\bar\041baz';
  return E'foo\\bar\041baz';
end;
/

select strtest();

drop function strtest();


-- Check variable scoping -- a var is not available in its own or prior
-- default expressions.

create or replace function scope_test() return int as
declare 
	x int := 42;
begin
  declare 
  	y int := x + 1;
    x int := x + 2;
  begin
    return x * 100 + y;
  end;
end;
/

select scope_test();

drop function scope_test();


--
-- Test access to call stack
--

create or replace function inner_func(int) returns int as $$
declare 
  _context text;
begin
  get diagnostics _context = pg_context;
  raise notice '***%***', _context;
  -- lets do it again, just for fun..
  get diagnostics _context = pg_context;
  raise notice '***%***', _context;
  raise notice 'lets make sure we didnt break anything';
  return 2 * $1;
end;
$$ language plisql;


create or replace function outer_func(int) return int as
declare
  myresult int;
begin
  raise notice 'calling down into inner_func()';
  myresult := inner_func($1);
  raise notice 'inner_func() done';
  return myresult;
end;
/


create or replace function outer_outer_func(int) return int as
declare
  myresult int;
begin
  raise notice 'calling down into outer_func()';
  myresult := outer_func($1);
  raise notice 'outer_func() done';
  return myresult;
end;
/

select outer_outer_func(10);
-- repeated call should to work
select outer_outer_func(20);

drop function outer_outer_func(int);
drop function outer_func(int);
drop function inner_func(int);


--
-- Check type parsing and record fetching from partitioned tables
--
CREATE TABLE partitioned_table (a int, b text) PARTITION BY LIST (a);
CREATE TABLE pt_part1 PARTITION OF partitioned_table FOR VALUES IN (1);
CREATE TABLE pt_part2 PARTITION OF partitioned_table FOR VALUES IN (2);

INSERT INTO partitioned_table VALUES (1, 'Row 1');
INSERT INTO partitioned_table VALUES (2, 'Row 2');

CREATE OR REPLACE FUNCTION get_from_partitioned_table(partitioned_table.a%type)
RETURN partitioned_table AS
DECLARE
    a_val partitioned_table.a%TYPE;
    result partitioned_table%ROWTYPE;
BEGIN
    a_val := $1;
    SELECT * INTO result FROM partitioned_table WHERE a = a_val;
    RETURN result;
END;
/


SELECT * FROM get_from_partitioned_table(1) AS t;

CREATE OR REPLACE FUNCTION list_partitioned_table()
RETURN SETOF partitioned_table.a%TYPE AS
DECLARE
    ro partitioned_table%ROWTYPE;
    a_val partitioned_table.a%TYPE;
BEGIN
    FOR ro IN SELECT * FROM partitioned_table ORDER BY a LOOP
        a_val := ro.a;
        RETURN NEXT a_val;
    END LOOP;
    RETURN;
END;
/

SELECT * FROM list_partitioned_table() AS t;

drop function get_from_partitioned_table;
drop function list_partitioned_table;

drop table pt_part1;
drop table pt_part2;
drop table partitioned_table;


-- Check that an unreserved keyword can be used as a variable name

create or replace function unreserved_test() returns int as $$
declare
  forward int := 21;
begin
  forward := forward * 2;
  return forward;
end
$$ language plisql;

select unreserved_test();

create or replace function unreserved_test() returns int as $$
declare
  return int := 42;
begin
  return := return + 1;
  return return;
end
$$ language plisql;

select unreserved_test();

create or replace function unreserved_test() returns int as $$
declare
  com int := 21;
begin
  com := com * 2;
  comment on function unreserved_test() is 'this is a test';
  return com;
end
$$ language plisql;

select unreserved_test();

select obj_description('unreserved_test()'::regprocedure, 'pg_proc');

drop function unreserved_test();


--
-- Test procedure
--
create table pro_tb(x int, y varchar(100));

create or replace procedure tpro1(a int, b varchar)
is
begin
	insert into pro_tb values(a, b);
end;
/

create or replace procedure tpro2
is
begin
	insert into pro_tb values(2, 'Two');
	insert into pro_tb values(3, 'Three');
end;
/


call tpro1(1, 'One');
select * from pro_tb;

call tpro2;
select * from pro_tb;

drop procedure tpro1;
drop procedure tpro2;
drop table pro_tb;


-- test foreach
create function foreach_test(anyarray)returns void 
as $$
declare 
	x int;
begin  
	foreach x in array $1  loop    
	 raise notice '%', x;  
	end loop;  
end;
$$ language plisql;

select foreach_test(ARRAY[1,2,3,4]);

drop function foreach_test;


-- test CASE
create or replace function tfunc(a char) returns void
as $$
declare 
	var varchar(20); 
begin  
	var :=  case a    
	 when 'A' THEN 'Excellent'  
	 when 'B' THEN 'Very good'   
	 when 'C' THEN 'good'   
	 when 'D' THEN 'bad'   
	 else 'no rules'  
	end;  
	raise info '%',var;
end;
$$ language plisql;

select tfunc('C');
select tfunc('a');

drop function tfunc(char);


create or replace function tfunc(a int) return void
as 
begin  
	case   
	 when a between 1 and 10 THEN   
	 	raise info '1< a < 10';   
	 when a between 10 and 100 THEN   
	 	raise info '10< a < 100';   
	 end case; 
end;
/


select tfunc(5);
drop function tfunc(int);


-- test COMMIT/ROLLBACK
create table tb_cr(x int, y varchar(100));
create or replace procedure transaction_test1()
AS $$
begin
	for i  in 0..9 LOOP 
	  INSERT INTO tb_cr values (i,'aaa'); 
	  IF i%2 = 0 THEN  
	    COMMIT; 
	  ELSE  
	    ROLLBACK; 
	  END IF;
	END LOOP;
END;
$$ language plisql;


call transaction_test1();

select * from tb_cr;

drop procedure transaction_test1();

-- test ASSERT
create or replace procedure assert_test() 
as $$
declare 
	x int;
begin 
	select count(*) into x from tb_cr;
	raise info 'x = %', x;
	assert x < 1,'there were over 1 iterm in table test';
end;
$$ language plisql;


call assert_test();

drop procedure assert_test();
drop table tb_cr;


-- test PL label
declare  
	a int := 1;
begin  
	<<loop_out>>  
	for I in 1 .. 5 loop    
	  if I > 3 then      
	    exit loop_out;    
	  end if;    
	  <<loop_in>>    
	  for J in 1 .. 5 loop      
	    if J > I then        
	      continue loop_in;      
	    end if;      
	    raise info 'I= %, J= %', I, J;   
	  end loop loop_in;  
	end loop loop_out;
end;
/

-- test riase EXCEPTION
create or replace function test_exp() return void 
as
begin    
	raise exception using message = 'S 167', detail = 'D 167', hint = 'H 167', errcode = 'P3333';
end;
/

select test_exp();

drop function test_exp();


--
-- test usage of transition tables in AFTER triggers
--

CREATE TABLE tran_table_base (id int PRIMARY KEY, val text);

CREATE OR REPLACE FUNCTION tran_table_base_ins_func()
  RETURNS trigger
AS $$
DECLARE
  t text;
  l text;
BEGIN
  t = '';
  FOR l IN EXECUTE
           $q$
             EXPLAIN (TIMING off, COSTS off, VERBOSE on)
             SELECT * FROM newtable
           $q$ LOOP
    t = t || l || E'\n';
  END LOOP;

  RAISE INFO '%', t;
  RETURN new;
END;
$$ LANGUAGE plisql;

CREATE TRIGGER tran_table_base_ins_trig
  AFTER INSERT ON tran_table_base
  REFERENCING OLD TABLE AS oldtable NEW TABLE AS newtable
  FOR EACH STATEMENT
  EXECUTE PROCEDURE tran_table_base_ins_func();

CREATE TRIGGER tran_table_base_ins_trig
  AFTER INSERT ON transition_table_base
  REFERENCING NEW TABLE AS newtable
  FOR EACH STATEMENT
  EXECUTE PROCEDURE tran_table_base_ins_func();

INSERT INTO tran_table_base VALUES (1, 'One'), (2, 'Two');
INSERT INTO tran_table_base VALUES (3, 'Three'), (4, 'Four');

SELECT * FROM tran_table_base;

CREATE OR REPLACE FUNCTION tran_table_base_upd_func()
  RETURNS trigger
AS $$
DECLARE
  t text;
  l text;
BEGIN
  t = '';
  FOR l IN EXECUTE
           $q$
             EXPLAIN (TIMING off, COSTS off, VERBOSE on)
             SELECT * FROM oldtable ot FULL JOIN newtable nt USING (id)
           $q$ LOOP
    t = t || l || E'\n';
  END LOOP;

  RAISE INFO '%', t;
  RETURN new;
END;
$$ LANGUAGE plisql;

CREATE TRIGGER tran_table_base_upd_trig
  AFTER UPDATE ON tran_table_base
  REFERENCING OLD TABLE AS oldtable NEW TABLE AS newtable
  FOR EACH STATEMENT
  EXECUTE PROCEDURE tran_table_base_upd_func();

UPDATE tran_table_base
  SET val = '*' || val || '*'
  WHERE id BETWEEN 2 AND 3;

SELECT * FROM tran_table_base;



drop function tran_table_base_ins_func() cascade;
drop function tran_table_base_upd_func() cascade;
drop table tran_table_base;



--
-- tests for per-statement triggers
--

CREATE TABLE main_table (a int unique, b int);

COPY main_table (a,b) FROM stdin;
5	10
20	20
30	10
50	35
80	15
\.

CREATE OR REPLACE FUNCTION trigger_func() RETURNS trigger  
AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %', TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;
$$ LANGUAGE plisql;

CREATE TRIGGER before_ins_stmt_trig BEFORE INSERT ON main_table
FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func('before_ins_stmt');

CREATE TRIGGER after_ins_stmt_trig AFTER INSERT ON main_table
FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func('after_ins_stmt');

--
-- if neither 'FOR EACH ROW' nor 'FOR EACH STATEMENT' was specified,
-- CREATE TRIGGER should default to 'FOR EACH STATEMENT'
--
CREATE TRIGGER after_upd_stmt_trig AFTER UPDATE ON main_table
EXECUTE PROCEDURE trigger_func('after_upd_stmt');

-- Both insert and update statement level triggers (before and after) should
-- fire.  Doesn't fire UPDATE before trigger, but only because one isn't
-- defined.
INSERT INTO main_table (a, b) VALUES (5, 10) ON CONFLICT (a)
  DO UPDATE SET b = EXCLUDED.b;

CREATE TRIGGER after_upd_row_trig AFTER UPDATE ON main_table
FOR EACH ROW EXECUTE PROCEDURE trigger_func('after_upd_row');

INSERT INTO main_table DEFAULT VALUES;

UPDATE main_table SET a = a + 1 WHERE b < 30;
-- UPDATE that effects zero rows should still call per-statement trigger
UPDATE main_table SET a = a + 2 WHERE b > 100;

-- constraint now unneeded
ALTER TABLE main_table DROP CONSTRAINT main_table_a_key;

-- COPY should fire per-row and per-statement INSERT triggers
COPY main_table (a, b) FROM stdin;
30	40
50	60
\.

SELECT * FROM main_table ORDER BY a, b;

--
-- test triggers with WHEN clause
--

CREATE TRIGGER modified_a BEFORE UPDATE OF a ON main_table
FOR EACH ROW WHEN (OLD.a <> NEW.a) EXECUTE PROCEDURE trigger_func('modified_a');
CREATE TRIGGER modified_any BEFORE UPDATE OF a ON main_table
FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE PROCEDURE trigger_func('modified_any');
CREATE TRIGGER insert_a AFTER INSERT ON main_table
FOR EACH ROW WHEN (NEW.a = 123) EXECUTE PROCEDURE trigger_func('insert_a');
CREATE TRIGGER delete_a AFTER DELETE ON main_table
FOR EACH ROW WHEN (OLD.a = 123) EXECUTE PROCEDURE trigger_func('delete_a');
CREATE TRIGGER insert_when BEFORE INSERT ON main_table
FOR EACH STATEMENT WHEN (true) EXECUTE PROCEDURE trigger_func('insert_when');
CREATE TRIGGER delete_when AFTER DELETE ON main_table
FOR EACH STATEMENT WHEN (true) EXECUTE PROCEDURE trigger_func('delete_when');
SELECT trigger_name, event_manipulation, event_object_schema, event_object_table,
       action_order, action_condition, action_orientation, action_timing,
       action_reference_old_table, action_reference_new_table
  FROM information_schema.triggers
  WHERE event_object_table IN ('main_table')
  ORDER BY trigger_name COLLATE "C", 2;
INSERT INTO main_table (a) VALUES (123), (456);
COPY main_table FROM stdin;
123	999
456	999
\.
DELETE FROM main_table WHERE a IN (123, 456);
UPDATE main_table SET a = 50, b = 60;
SELECT * FROM main_table ORDER BY a, b;
SELECT pg_get_triggerdef(oid, true) FROM pg_trigger WHERE tgrelid = 'main_table'::regclass AND tgname = 'modified_a';
SELECT pg_get_triggerdef(oid, false) FROM pg_trigger WHERE tgrelid = 'main_table'::regclass AND tgname = 'modified_a';
SELECT pg_get_triggerdef(oid, true) FROM pg_trigger WHERE tgrelid = 'main_table'::regclass AND tgname = 'modified_any';

-- Test RENAME TRIGGER
ALTER TRIGGER modified_a ON main_table RENAME TO modified_modified_a;
SELECT count(*) FROM pg_trigger WHERE tgrelid = 'main_table'::regclass AND tgname = 'modified_a';
SELECT count(*) FROM pg_trigger WHERE tgrelid = 'main_table'::regclass AND tgname = 'modified_modified_a';

DROP TRIGGER modified_modified_a ON main_table;
DROP TRIGGER modified_any ON main_table;
DROP TRIGGER insert_a ON main_table;
DROP TRIGGER delete_a ON main_table;
DROP TRIGGER insert_when ON main_table;
DROP TRIGGER delete_when ON main_table;

DROP FUNCTION trigger_func cascade;

DROP TABLE main_table;


CREATE TABLE range_parted (
	a text,
	b bigint,
	c numeric,
	d int,
	e varchar
) PARTITION BY RANGE (a, b);


CREATE OR REPLACE FUNCTION triggerfunc() returns trigger  
as $$
begin
   raise notice 'trigger = % fired on table % during %',
                 TG_NAME, TG_TABLE_NAME, TG_OP;
   return null;
end;
$$ language plisql;

CREATE TRIGGER parent_update_trig
  AFTER UPDATE ON range_parted for each statement execute procedure triggerfunc();

UPDATE range_parted set c = c - 50 WHERE c > 97;

DROP TRIGGER parent_update_trig ON range_parted;
DROP FUNCTION triggerfunc;
DROP TABLE range_parted;


-- dump trigger data
CREATE TABLE trigger_test (
        i int,
        v varchar
);

CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger
AS $$
declare
	argstr text;
	relid text;

begin
	relid := TG_relid::regclass;

	-- plpgsql can't discover its trigger data in a hash like perl and python
	-- can, or by a sort of reflection like tcl can,
	-- so we have to hard code the names.
	raise NOTICE 'TG_NAME: %', TG_name;
	raise NOTICE 'TG_WHEN: %', TG_when;
	raise NOTICE 'TG_LEVEL: %', TG_level;
	raise NOTICE 'TG_OP: %', TG_op;
	raise NOTICE 'TG_RELID::regclass: %', relid;
	raise NOTICE 'TG_RELNAME: %', TG_relname;
	raise NOTICE 'TG_TABLE_NAME: %', TG_table_name;
	raise NOTICE 'TG_TABLE_SCHEMA: %', TG_table_schema;
	raise NOTICE 'TG_NARGS: %', TG_nargs;

	argstr := '[';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;
	argstr := argstr || ']';
	raise NOTICE 'TG_ARGV: %', argstr;

	if TG_OP != 'INSERT' then
		raise NOTICE 'OLD: %', OLD;
	end if;

	if TG_OP != 'DELETE' then
		raise NOTICE 'NEW: %', NEW;
	end if;

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;

end;
$$ LANGUAGE plisql;


CREATE TRIGGER show_trigger_data_trig
BEFORE INSERT OR UPDATE OR DELETE ON trigger_test
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

insert into trigger_test values(1,'insert');
update trigger_test set v = 'update' where i = 1;
delete from trigger_test;

DROP TRIGGER show_trigger_data_trig on trigger_test;
DROP FUNCTION trigger_data();
DROP TABLE trigger_test;

--event trigger
create function test_event_trigger() returns event_trigger as $$
BEGIN
    RAISE NOTICE 'test_event_trigger: % %', tg_event, tg_tag;
END
$$ language plisql;

create event trigger regress_event_trigger on ddl_command_start
   execute procedure test_event_trigger();
create table test(x int,y varchar(20));
drop function test_event_trigger cascade;
drop table test;

--test stmt_set
create or replace procedure set_test1() as
$$
begin
RESET default_tablespace;
end;
$$ language plisql;
call set_test1();
drop procedure set_test1;

--
-- support stand alone PL/iSQL procedures can calling
-- another procedure from within without call keyword
--
CREATE OR REPLACE PROCEDURE pro1(in1 text)
IS
BEGIN
	RAISE INFO 'pro1 => %', in1;
END;
/

CREATE OR REPLACE PROCEDURE pro2(in2 text)
IS
BEGIN
	pro1('Hello');
	RAISE INFO 'pro2 => %', in2;
END;
/

call pro2('IvorySQL');

DROP PROCEDURE pro1;
DROP PROCEDURE pro2;

create table tab_p (a int, b text);

create or replace procedure tpro1(x int, y text)
is
begin
	insert into tab_p(a,b) values (x, y);
end;
/

create or replace procedure tpro2(a int, b text)
is
begin
	tpro1(a, b);
end;
/

call tpro2(2022, 'IvorySQL Database');

select * from tab_p;

drop procedure tpro2;
drop procedure tpro1;
drop table tab_p;

--test various combinations for anonymous blocks
DECLARE x CURSOR FOR SELECT * from pg_class;
DECLARE x BINARY CURSOR FOR select * from pg_class;
DECLARE x ASENSITIVE CURSOR FOR select * from pg_class;
DECLARE x INSENSITIVE CURSOR FOR select * from pg_class;
DECLARE x SCROLL CURSOR FOR select * from pg_class;
DECLARE x NO SCROLL CURSOR FOR select * from pg_class;


BEGIN; END;
BEGIN WORK; END;
BEGIN TRANSACTION;
END;
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
END;
BEGIN ISOLATION LEVEL SERIALIZABLE;
END;
BEGIN READ WRITE;
END;
BEGIN NOT DEFERRABLE;
END;

DECLARE
	x int;
BEGIN
	x := 10;
	declare
    x int;
	begin
    x := 11;
    raise info 'x =>>> %', x;
	end;
  raise info 'x =>>> %', x;
END;
/

begin
  raise info 'x =>>> %', 0;
  declare
    x int;
	 begin
    x := 10;
    raise info 'x =>>> %', x;
  end;
end;
/

declare
a int := 10;
b int := 2;
begin
a := a
/ b;
raise info 'a = %', a;
end;
/

declare
a int := 10;
b int := 2;
begin
a := a
/b;
raise info 'a = %', a;
end;
/

declare
a int := 10;
b int := 2;
begin
a := a
/
b;
raise info 'a = %', a;
end;
/

BEGIN
  BEGIN
    RAISE syntax_error;
  EXCEPTION
    WHEN syntax_error THEN
      BEGIN
        raise notice 'exception % thrown in inner block, reraising', sqlerrm;
        RAISE;
    EXCEPTION
      WHEN OTHERS THEN
        raise notice 'RIGHT - exception % caught in inner block', sqlerrm;
    END;
  END;
EXCEPTION
  WHEN OTHERS THEN
    raise notice 'WRONG - exception % caught in outer block', sqlerrm;
END;
/

declare
  cursor c(r1 integer, r2 integer)
       for select * from generate_series(r1,r2) i;
  cursor c2
       for select * from generate_series(41,43) i;
begin
  for r in c(5,7) loop
    raise notice '% from %', r.i, c;
  end loop;
  -- again, to test if cursor was closed properly
  for r in c(9,10) loop
    raise notice '% from %', r.i, c;
  end loop;
  -- and test a parameterless cursor
  for r in c2 loop
    raise notice '% from %', r.i, c2;
  end loop;
  -- and try it with a hand-assigned name
  raise notice 'after loop, c2 = %', c2;
  c2 := 'special_name';
  for r in c2 loop
    raise notice '% from %', r.i, c2;
  end loop;
  raise notice 'after loop, c2 = %', c2;
  -- and try it with a generated name
  -- (which we can't show in the output because it's variable)
  c2 := null;
  for r in c2 loop
    raise notice '%', r.i;
  end loop;
  raise notice 'after loop, c2 = %', c2;
  return;
end;
/

declare _sqlstate text;
        _message text;
        _context text;
begin
  perform zero_divide();
exception when others then
  get stacked diagnostics
        _sqlstate = returned_sqlstate,
        _message = message_text,
        _context = pg_exception_context;
  raise notice 'sqlstate: %, message: %, context: [%]',
    _sqlstate, _message, replace(_context, E'\n', ' <- ');
end;
/
