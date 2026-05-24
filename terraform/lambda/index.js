exports.handler = async (event) => {
    // Debug: Log the entire event to see what's actually being received
    console.log("Full event:", JSON.stringify(event, null, 2));
    
    // For HTTP API (v2) - correct structure
    const securityEvent = {
        eventType: "API_REQUEST",
        timestamp: new Date().toISOString(),
        sourceIP: event.requestContext?.http?.sourceIp || 
                  event.requestContext?.identity?.sourceIp || 
                  event.headers?.["x-forwarded-for"]?.split(",")[0]?.trim() ||
                  "unknown",
        route: event.requestContext?.http?.path || 
               event.rawPath || 
               event.path || 
               "unknown",
        userAgent: event.headers?.["user-agent"] || 
                   event.headers?.["User-Agent"] ||
                   "unknown",
        // Additional useful info for debugging
        method: event.requestContext?.http?.method || event.httpMethod || "unknown"
    };

    console.log(JSON.stringify(securityEvent));

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "AWS SOC Demo API is running",
            securityEvent,
            //receivedEvent: event // Remove this in production, just for debugging
        })
    };
};
//Compress-Archive -Path index.js -DestinationPath function.zip -Force
