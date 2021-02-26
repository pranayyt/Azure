# Azure.TumblingWindowTriggerStartTime

We love #Azure, all the services and especially DataFactory! and how it orchestrated our pipelines and eveyday monitoring tasks. But sometimes things doesn't go as planned and recently i met an unusual problem. 

**Error :** 
After updating the tumbling window trigger time, i deployed the ARM Templates. Which resulted in the following error:

```
"code":"DeploymentFailed","message":"At least one resource deployment operation failed.
 Please list deployment operations for details. Please see https://aka.ms/DeployOperations for usage 
details.","details":[{"code":"BadRequest","message":"{\r\n \"error\": {\r\n \"code\": 
\"TumblingWindowTriggerStartTimeUpdateNotAllowed\",\r\n \"message\": \"Start time cannot be updated for 
Tumbling Window Trigger.null\",\r\n \"target\": null,\r\n \"details\": null\r\n }\r\n}"}]}
```
After conversation with #Microsoft and after giving a thought, I decided to write a workaround. 
Below is the flow diagram.

![alt text](https://github.com/pranayyt/Azure.TumblingWindowTriggerStartTime/blob/main/FlowDiagram.jpg?raw=true)

