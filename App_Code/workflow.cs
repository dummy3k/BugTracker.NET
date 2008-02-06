/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Web;
using System.Web.UI.WebControls;

namespace btnet
{

// This is sample code that gives you an idea of how you could customize the 
// workflow, i.e, the change in bug statuses.  
 
    public class Workflow
    {
        public static void fill_status_dropdown(
            DataRow bug,  // null if a new bug, otherwise the state of the bug now in the db
            User user, // the currently logged in user
            System.Web.UI.WebControls.ListItemCollection statuses) // the options in the dropdown
        {
            // If you do nothing here, by default the app will fill the status 
            // dropdown with all the statuses in the database.

            // But, if you put something in the list of statuses, then the app
            // will use YOUR list instead of the default list.

            // Uncomment the next line to play with the sample code.
            //fill_status_dropdown_sample(bug, user, statuses);
        }

        // Just to give you an idea of what you could do...
        private static void fill_status_dropdown_sample(
            DataRow bug,  // null if a new bug, otherwise the way the bug is now in the db
            User user, // the currently logged in user
            System.Web.UI.WebControls.ListItemCollection statuses) // the options in the dropdown
        {

            if (bug != null) // existing bug
            {
                // Get the bug's current status.
                // See "get_bug_datarow()" in bug.cs for the sql
                int status = (int) bug["status"];
                string status_name = (string) bug["status_name"];

                if (status_name == "new") 
                {
                    // always add the option corresponding to the bug's current status
                    statuses.Add(new ListItem(
                        status_name, 
                        Convert.ToString(status)));  

                    // These are the only two valid statuses 
                    statuses.Add(new ListItem("in progress", "2")); 
                    statuses.Add(new ListItem("checked in", "3")); 
                }
                else
                {
                    // no special logic
                }
            }
            else // bug hasn't been entered yet
            {
                statuses.Add(new ListItem("new", "1"));
            }
        }
    }; // end class
}
