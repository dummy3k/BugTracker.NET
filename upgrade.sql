-- Run this, or portions of this, to upgrade from one
-- version to another.   Newer entries are at the bottom.


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 1.9.8 to 1.9.9
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table users add us_auto_subscribe_reported_bugs int null default(0)
update users set us_auto_subscribe_reported_bugs = 0

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.0.6 to 2.0.7
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table bug_attachments add ba_comment int null 
 
/* 
The SQL below might be something you want to try. It attempts to guess 
the relationship of an attachment to a comment by looking at how  
close in time they were added. If it's just a couple seconds a part, 
I assume they are related. For me, where I have just a few users 
on the system, this heuristic makes sense. I wouldn't use it if 
I had a lot of users. 
*/ 
 
select ba_id, bc_id  
into #t  
from bug_attachments 
inner join bug_comments on ba_bug = bc_bug and  
abs(datediff(s,ba_uploaded_date, bc_date)) < 4 -- 3 seconds or less 
 
update bug_attachments 
set ba_comment = #t.bc_id 
from #t where bug_attachments.ba_id = #t.ba_id 
 
drop table #t 

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.1.5 to 2.1.6
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table users
   add us_reported_notifications int not null default(4),
       us_assigned_notifications int not null default(4),
       us_subscribed_notifications int not null default(4)
go

update users
   set us_reported_notifications = 1, us_assigned_notifications = 1, us_subscribed_notifications = 1
   where isnull(us_only_status_change_notifications, 0) = 0 and isnull(us_only_new_bug_notifications, 0) = 1

update users
   set us_reported_notifications = 2, us_assigned_notifications = 2, us_subscribed_notifications = 2
   where isnull(us_only_status_change_notifications, 0) = 1
go

declare @defaults cursor
declare @default varchar(50)
set @defaults = cursor for
   select name from sysobjects 
      where id in
            (
               select cdefault from syscolumns 
                  where name in ('us_only_status_change_notifications', 'us_only_new_bug_notifications')
            )

open @defaults
fetch next from @defaults into @default
while (@@fetch_status=0) begin
   execute('alter table users drop constraint ' + @default)
   fetch next from @defaults into @default
end
close @defaults
deallocate @defaults
go

alter table users
   drop column us_only_status_change_notifications,
      us_only_new_bug_notifications
go

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.1.7 to 2.1.8
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

--  TRY THIS ON A BACKUP FIRST!

-- create a new table to hold the comments and the attachments
create table bug_posts
(
bp_id int identity primary key not null,
bp_bug int not null,
bp_type varchar(8) not null,
bp_user int not null,
bp_date datetime not null,
bp_comment ntext not null,
bp_email_from nvarchar(800) null,
bp_email_to nvarchar(800) null,
bp_file nvarchar(1000) null,
bp_size int null,
bp_content_type nvarchar(200) null,
bp_parent int null,
bp_original_comment_id int null
)

-- insert the attachments, but we want to 
-- keep the id's because they relate to 
-- the uploaded file names.

set identity_insert bug_posts on 

insert into bug_posts (
bp_id, bp_bug, bp_type, 
bp_user, bp_date, bp_comment, 
bp_file, bp_size, bp_content_type, 
bp_parent)
select 
ba_id, ba_bug, 'file', 
ba_uploaded_user, ba_uploaded_date, ba_desc, 
ba_file, ba_size, ba_content_type,
ba_comment
from bug_attachments

set identity_insert bug_posts off

-- insert the comments.  id's don't matter
insert into bug_posts (
bp_bug, bp_type, 
bp_user, bp_date, bp_comment, 
bp_email_from, bp_email_to,
bp_original_comment_id)

select 
bc_bug, bc_type,
bc_user, bc_date, bc_comment, 
bc_email_from, bc_email_to
bc_comment, bc_id
from bug_comments

-- the email attachments need to point to new parents
select a.bp_id a, b.bp_id b
into #t
from bug_posts a
inner join bug_posts b on a.bp_parent =
b.bp_original_comment_id
where a.bp_parent is not null

update bug_posts set bp_parent = b
from #t 
where bp_id = a

create index bp_index_1 on bug_posts (bp_bug)

-- get rid of the column we needed just for the conversion
alter table bug_posts drop column bp_original_comment_id

-- Just in case, hide, but don't drop the original tables
-- You can drop them if you want.
exec sp_rename bug_attachments, bug_attachments_obsolete
exec sp_rename bug_comments, bug_comments_obsolete


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.2.2 to 2.2.3
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------


alter table users add us_signature nvarchar(1000) null


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.2.8 to 2.2.9
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table projects add pj_default int not null default(0)
alter table categories add ct_default int not null default(0)
alter table priorities add pr_default int not null default(0)
alter table statuses add st_default int not null default(0)
alter table user_defined_attribute add udf_default int not null default(0)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.3.1 to 2.3.2
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_relationships
(
re_id int identity primary key not null,
re_bug1 int not null,
re_bug2 int not null,
re_type nvarchar(100) null
)

create unique index re_index_1 on bug_relationships (re_bug1, re_bug2)
create unique index re_index_2 on bug_relationships (re_bug2, re_bug1)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.3.9 to 2.4.0
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table custom_col_metadata
(
ccm_colorder int not null,
ccm_dropdown_vals nvarchar(1000) not null default('')
)

create unique index cdv_index on custom_col_metadata (ccm_colorder)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.4.1 to 2.4.2
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table custom_col_metadata add ccm_sort_seq int default(0)
alter table custom_col_metadata add ccm_dropdown_type varchar(20) null

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.4.5 to 2.4.6
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_file_revisions
(
bfr_id int identity primary key not null,
bfr_bug int not null,
bfr_revision int not null,
bfr_action nvarchar(8) null,
bfr_file nvarchar(400) null,
bfr_date datetime not null
)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.4.8 to 2.4.9
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- add a couple new columns to existing tables
alter table bug_posts add bp_comment_search ntext null
alter table users add us_use_fckeditor int not null default(0)
-- increase the size of the column
alter table bug_relationships alter column re_type nvarchar(500)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.4.9 to 2.5.0
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table users add us_enable_bug_list_popups int not null default(1)
alter table users add us_created_user int not null default(1)
alter table project_user_xref add pu_admin int not null default(0)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.5.7 to 2.5.8
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table users add us_external_user int not null default(0)
alter table users add us_can_be_assigned_to int not null default(1)

alter table users add us_can_edit_sql int not null default(0)
alter table users add us_can_delete_bug int not null default(0)
alter table users add us_can_edit_and_delete_posts int not null default(0)
alter table users add us_can_merge_bugs int not null default(0)
alter table users add us_can_mass_edit_bugs int not null default(0)
alter table users add us_can_use_reports int not null default(0)
alter table users add us_can_edit_reports int not null default(0)

alter table bug_posts add bp_hidden_from_external_users int not null default(0)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.5.9 to 2.6.0
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- Don't forget to replace your Subversion post-commit hook script too.

-- Step #1 - Create the new tables

/* SVN REVISION  */

create table svn_revisions
(
svnrev_id int identity primary key not null,
svnrev_revision int not null,
svnrev_bug int not null,
svnrev_repository nvarchar(400) not null,
svnrev_author nvarchar(100) not null,
svnrev_svn_date nvarchar(100) not null,
svnrev_btnet_date datetime not null,
svnrev_msg ntext not null
)

create index svn_bug_index on svn_revisions (svnrev_bug)


/* SVN AFFECTED PATH */

create table svn_affected_paths
(
svnap_id int identity primary key not null,
svnap_svnrev_id int not null,
svnap_action nvarchar(8) not null,
svnap_path nvarchar(400) not null
)

create index svn_revision_index on svn_affected_paths (svnap_svnrev_id)


-- Step #2 - Copy data from obsolete bug_file_revisions table into new tables,
-- if you have been using Subversion integration in earlier BugTracker.NET
-- versions.

insert into svn_revisions
(svnrev_revision, 
svnrev_bug,
svnrev_repository,
svnrev_author,
svnrev_svn_date,
svnrev_btnet_date,
svnrev_msg)
select distinct bfr_revision, bfr_bug, '', '', convert(varchar(400),bfr_date), bfr_date,''
from bug_file_revisions

insert into svn_affected_paths
(svnap_svnrev_id,
svnap_action,
svnap_path)
select distinct svnrev_id, bfr_action, bfr_file
from bug_file_revisions
inner join svn_revisions on bfr_revision = svnrev_revision

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.6.3 to 2.6.4
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_post_attachments
(
bpa_id int identity primary key not null,
bpa_post int not null,
bpa_content image not null
)

create unique index bpa_index on bug_post_attachments (bpa_post)


alter table projects add pj_description nvarchar(200) null
alter table projects add pj_subversion_repository_url nvarchar(255) null
alter table projects add pj_subversion_username nvarchar(100) null
alter table projects add pj_subversion_password nvarchar(80) null
alter table projects add pj_websvn_url nvarchar(100) null


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.6.6 to 2.6.7
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

/* after running this sql, users will have the same permissions they
had before */

alter table queries add qu_org int null

alter table users add us_org int not null default(1)
go

create table orgs
(
og_id int identity primary key not null,
og_name nvarchar(80) not null,
og_non_admins_can_use int not null default(0),
og_external_user int not null default(0), /* external user can't view post marked internal */
og_can_be_assigned_to int not null default(1),
og_can_edit_sql int not null default(0),
og_can_delete_bug int not null default(0),
og_can_edit_and_delete_posts int not null default(0),
og_can_merge_bugs int not null default(0),
og_can_mass_edit_bugs int not null default(0),
og_can_use_reports int not null default(0),
og_can_edit_reports int not null default(0)
)

create unique index unique_og_name on orgs (og_name)

/* Generate some orgs.  Manufacture their names based on the users' permissions */
insert into orgs
(og_name,
og_external_user,
og_can_be_assigned_to,
og_can_edit_sql,
og_can_delete_bug,
og_can_edit_and_delete_posts,
og_can_merge_bugs,
og_can_mass_edit_bugs,
og_can_use_reports,
og_can_edit_reports)
select distinct
'r-' +
case when us_external_user = 1             then 'extern,' else '' end +
case when us_can_be_assigned_to = 1        then 'assgnbl,' else '' end +
case when us_can_edit_sql = 1              then 'edt_sql,' else '' end +
case when us_can_delete_bug = 1            then 'del_bug,' else '' end +
case when us_can_edit_and_delete_posts = 1 then 'edt_post,' else '' end +
case when us_can_merge_bugs = 1            then 'mrge,' else '' end +
case when us_can_mass_edit_bugs = 1        then 'mass_edit,' else '' end +
case when us_can_use_reports = 1           then 'use_rpt,' else '' end +
case when us_can_edit_reports = 1          then 'edt_rpt' else '' end,

us_external_user,
us_can_be_assigned_to,
us_can_edit_sql,
us_can_delete_bug,
us_can_edit_and_delete_posts,
us_can_merge_bugs,
us_can_mass_edit_bugs,
us_can_use_reports,
us_can_edit_reports
from users

/* Update the users so that their us_org column points to the orgs we just created */

DECLARE @us_id int
DECLARE @org_name nvarchar(80)
DECLARE @org_id int

DECLARE my_cursor CURSOR FOR
SELECT us_id,
'r-' +
case when us_external_user = 1             then 'extern,' else '' end +
case when us_can_be_assigned_to = 1        then 'assgnbl,' else '' end +
case when us_can_edit_sql = 1              then 'edt_sql,' else '' end +
case when us_can_delete_bug = 1            then 'del_bug,' else '' end +
case when us_can_edit_and_delete_posts = 1 then 'edt_post,' else '' end +
case when us_can_merge_bugs = 1            then 'mrge,' else '' end +
case when us_can_mass_edit_bugs = 1        then 'mass_edit,' else '' end +
case when us_can_use_reports = 1           then 'use_rpt,' else '' end +
case when us_can_edit_reports = 1          then 'edt_rpt' else '' end
FROM users

OPEN my_cursor

FETCH NEXT FROM my_cursor
INTO @us_id, @org_name

WHILE @@FETCH_STATUS = 0
BEGIN

   select @org_id = og_id from orgs where og_name = @org_name
   update users set us_org = @org_id where us_id = @us_id	
   FETCH NEXT FROM my_cursor
   INTO @us_id, @org_name
END

CLOSE my_cursor
DEALLOCATE my_cursor

/*
Several columns on the user table are now obsolete. They aren't hurting anything, but 
you can drop the obsolete columns using the SQL below and some patience.
When you run the sql below it will fail with an error saying
"failed because one or more objects access this column"
because of the columns have default values.  You can drop the defaults one by one
as you learn their names using this syntax:
alter table users drop constraint [DF__ the generated name goes here]
*/

/*
alter table users drop column us_external_user
alter table users drop column us_can_be_assigned_to
alter table users drop column us_can_edit_sql
alter table users drop column us_can_delete_bug
alter table users drop column us_can_edit_and_delete_posts
alter table users drop column us_can_merge_bugs
alter table users drop column us_can_mass_edit_bugs
alter table users drop column us_can_use_reports
alter table users drop column us_can_edit_reports
*/


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.6.7 to 2.6.8
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table bugs add bg_org int not null default(0)
alter table orgs add og_other_orgs_permission_level int not null default(2)


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.6.8 to 2.6.9
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_user_flags
(
fl_bug int not null,
fl_user int not null,
fl_flag int not null
)

create unique index fl_index_1 on bug_user_flags (fl_bug, fl_user)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.7.2 to 2.7.3
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table bug_relationships add re_direction int not null default(0)

alter table orgs add og_category_field_permission_level int not null default(2)
alter table orgs add og_priority_field_permission_level int not null default(2)
alter table orgs add og_assigned_to_field_permission_level int not null default(2)
alter table orgs add og_status_field_permission_level int not null default(2)
alter table orgs add og_project_field_permission_level int not null default(2)
alter table orgs add og_org_field_permission_level int not null default(2)
alter table orgs add og_udf_field_permission_level int not null default(2)


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.7.3 to 2.7.4
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table users add us_salt int null


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.7.7 to 2.7.8
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table emailed_links
(
el_id char(37) not null,
el_date datetime not null default(getdate()),
el_email nvarchar(120) not null,
el_action nvarchar(20) not null, -- "registration" or "forgot"
el_username nvarchar(40) null,
el_user_id int null,
el_salt int null,
el_password nvarchar(64) null,
el_firstname nvarchar(60) null,
el_lastname nvarchar(60) null
)


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.7.9 to 2.8.0
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------


create table queued_notifications
(
qn_id int identity primary key not null,
qn_date_created datetime not null,
qn_bug int not null,
qn_user int not null,
qn_status nvarchar(30) not null,
qn_retries int not null,
qn_last_exception nvarchar(1000),
qn_to nvarchar(200) not null,
qn_from nvarchar(200) not null,
qn_subject nvarchar(200) not null,
qn_body ntext not null
)


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.8.0 to 2.8.1
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table dashboard_items
(
ds_id int identity primary key not null,
ds_user int not null,
ds_report int not null,
ds_chart_type varchar(8) not null,
ds_col int not null,
ds_row int not null
)

create index ds_user_index on dashboard_items (ds_user)

alter table users add us_most_recent_login_datetime datetime null

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.8.3 to 2.8.4
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

update custom_col_metadata set 
ccm_dropdown_type = '' where ccm_dropdown_type = 'not a dropdown'

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.8.7 to 2.8.8
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table projects alter column pj_websvn_url nvarchar(255) null
alter table queued_notifications alter column qn_subject nvarchar(400) not null


-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.9.0 to 2.9.1
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table bugs add bg_tags nvarchar(200) null
alter table orgs add og_tags_field_permission_level int not null default(2)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.9.1 to 2.9.2
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_user_seen
(
sn_bug int not null,
sn_user int not null,
sn_seen int not null
)

create unique index sn_index_1 on bug_user_seen (sn_bug, sn_user)

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 2.9.3 to 2.9.4
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

alter table bug_posts add bp_email_cc nvarchar(800) null

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- upgrade from 3.0.3 to 3.0.4
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

create table bug_tasks
(
tsk_id int identity primary key not null,
tsk_bug int not null,
tsk_created_user int not null,
tsk_created_date datetime not null,
tsk_last_updated_user int not null,
tsk_last_updated_date datetime not null,

tsk_assigned_to_user int null,
tsk_planned_start_date datetime null,
tsk_actual_start_date datetime null,
tsk_planned_end_date datetime null,
tsk_actual_end_date datetime null,
tsk_planned_duration decimal(6,2) null,
tsk_actual_duration decimal(6,2) null,
tsk_duration_units nvarchar(20) null,
tsk_percent_complete int null,
tsk_status int null,
tsk_sort_sequence int null,
tsk_description nvarchar(400) null,
)

create index tsk_index_1 on bug_tasks (tsk_bug)
