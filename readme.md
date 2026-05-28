## *Find Latest Restarter*    
After having the same server restarted while I was working on something not once, but **twice**, I decided - it's time to stand up to the irresponsible restarters of this world.  
This tool will try and find the last person who performed a restart to the computer you're using,  
and allow you to choose what happens next.    
How the app works:  
 - Searches for the latest windows event with 1074 ID, which represents planned shutdowns
 - Fetches the user ID
 - Searches the entire AD forest for a user with that SID
 - Displays the user's name, and gives you the option to disable it  
  
**Notice**  
 - It only works in AD domain environments, and only if you have appropriate permissions
 - The variable *ActuallyDisableUser* sets the usability. If it's true, the user will actually be disabled, and if not - well... it won't  

### **Use at your own risk :)**