/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Collections.Generic;

namespace btnet
{
    public class User
    {
        public int usid = 0;
        public string username = "";
        public string fullname = "";
        public string email = "";
        public bool is_admin = false;
        public bool is_project_admin = false;
        public bool is_guest = false;
        public bool adds_not_allowed = false;
        public int bugs_per_page = 10;
        public bool enable_popups = true;
        public bool use_fckeditor = false;

        public bool external_user = false;
        public bool can_edit_sql = false;
        public bool can_delete_bug = false;

        public bool can_edit_and_delete_posts = false;
        public bool can_merge_bugs = false;
        public bool can_mass_edit_bugs = false;

        public bool can_use_reports = false;
        public bool can_edit_reports = false;
        public bool can_be_assigned_to = true;

        public int other_orgs_permission_level = Security.PERMISSION_ALL;
        public int org = 0;
        public string org_name = "";
        public int forced_project = 0;

        public int assigned_to_field_permission_level = Security.PERMISSION_ALL;
        public int status_field_permission_level = Security.PERMISSION_ALL;
        public int category_field_permission_level = Security.PERMISSION_ALL;
        public int tags_field_permission_level = Security.PERMISSION_ALL;
        public int priority_field_permission_level = Security.PERMISSION_ALL;
        public int project_field_permission_level = Security.PERMISSION_ALL;
        public int org_field_permission_level = Security.PERMISSION_ALL;
        public int udf_field_permission_level = Security.PERMISSION_ALL;
        
        public Dictionary<string,int> dict_custom_field_permission_level = new Dictionary<string, int>();

        public void set_from_db(DbUtil dbutil, DataRow dr)
        {
            this.usid = Convert.ToInt32(dr["us_id"]);
            this.username = (string)dr["us_username"];
            this.email = (string)dr["us_email"];

            this.bugs_per_page = Convert.ToInt32(dr["us_bugs_per_page"]);
			if (Util.get_setting("DisableFCKEditor","0") == "1")
			{
				this.use_fckeditor = false;
			}
			else
			{
            	this.use_fckeditor = Convert.ToBoolean(dr["us_use_fckeditor"]);
			}
            this.enable_popups = Convert.ToBoolean(dr["us_enable_bug_list_popups"]);

            this.external_user = Convert.ToBoolean(dr["og_external_user"]);
            this.can_edit_sql = Convert.ToBoolean(dr["og_can_edit_sql"]);
            this.can_delete_bug = Convert.ToBoolean(dr["og_can_delete_bug"]);
            this.can_edit_and_delete_posts = Convert.ToBoolean(dr["og_can_edit_and_delete_posts"]);
            this.can_merge_bugs = Convert.ToBoolean(dr["og_can_merge_bugs"]);
            this.can_mass_edit_bugs = Convert.ToBoolean(dr["og_can_mass_edit_bugs"]);
            this.can_use_reports = Convert.ToBoolean(dr["og_can_use_reports"]);
            this.can_edit_reports = Convert.ToBoolean(dr["og_can_edit_reports"]);
            this.can_be_assigned_to = Convert.ToBoolean(dr["og_can_be_assigned_to"]);
            this.other_orgs_permission_level = (int)dr["og_other_orgs_permission_level"];
            this.org = (int)dr["og_id"];
            this.org_name = (string) dr["og_name"];
            this.forced_project = (int)dr["us_forced_project"];

            this.category_field_permission_level = (int)dr["og_category_field_permission_level"];

            if (Util.get_setting("EnableTags","0") == "1")
            {
            	this.tags_field_permission_level = (int)dr["og_tags_field_permission_level"];
			}
			else
			{
				this.tags_field_permission_level = Security.PERMISSION_NONE;
			}
            this.priority_field_permission_level = (int)dr["og_priority_field_permission_level"];
            this.assigned_to_field_permission_level = (int)dr["og_assigned_to_field_permission_level"];
            this.status_field_permission_level = (int)dr["og_status_field_permission_level"];
            this.project_field_permission_level = (int)dr["og_project_field_permission_level"];
            this.org_field_permission_level = (int)dr["og_org_field_permission_level"];
            this.udf_field_permission_level = (int)dr["og_udf_field_permission_level"];

			DataSet ds_custom = Util.get_custom_columns(dbutil);
			foreach (DataRow dr_custom in ds_custom.Tables[0].Rows)
			{
				string bg_name = (string)dr_custom["name"];
				string og_name = "og_" 
					+ (string)dr_custom["name"]
					+ "_field_permission_level";
				
				try
				{
					dict_custom_field_permission_level[bg_name] = (int) dr_custom[og_name];
				}
				catch(Exception)
				{
					// add it if it's missing
					dbutil.execute_nonquery("alter table orgs add [" 
						+ og_name
						+ "] int null default(2)");
					dict_custom_field_permission_level[bg_name] = Security.PERMISSION_ALL;
				}
				
			}

            if (((string)dr["us_firstname"]).Trim().Length == 0)
            {
                this.fullname = (string)dr["us_lastname"];
            }
            else
            {
                this.fullname = (string)dr["us_lastname"] + ", " + (string)dr["us_firstname"];
            }


            if ((int)dr["us_admin"] == 1)
            {
                this.is_admin = true;
            }
            else
            {
                if ((int)dr["project_admin"] > 0)
                {
                    this.is_project_admin = true;
                }
                else
                {
                    if (this.username.ToLower() == "guest")
                    {
                        this.is_guest = true;
                    }
                }
            }


            // if user is forced to a specific project, and doesn't have
            // at least reporter permission on that project, than user
            // can't add bugs
            if ((int)dr["us_forced_project"] != 0)
            {
                if ((int)dr["pu_permission_level"] == Security.PERMISSION_READONLY
                || (int)dr["pu_permission_level"] == Security.PERMISSION_NONE)
                {
                    this.adds_not_allowed = true;
                }
            }
        }
    }; // end class
}
