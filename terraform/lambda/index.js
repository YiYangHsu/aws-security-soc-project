exports.handler = async (event) => {
    console.log("Security event received:", JSON.stringify(event));

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "AWS SOC Demo API is running",
            timestamp: new Date().toISOString()
        })
    };
};

