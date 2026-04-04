from prefect import get_client
import asyncio

async def get_application_details():
    async with get_client() as client:
        # Get flows
        flows = await client.read_flows()
        print("Flows:")
        for flow in flows[:2]:  # Display first 2
            print(f"Flow ID: {flow.id}, Name: {flow.name}")

        # Get deployments
        deployments = await client.read_deployments()
        print("\nDeployments:")
        for deployment in deployments[:2]:  # Display first 2
            print(f"Deployment ID: {deployment.id}, Name: {deployment.name}")

if __name__ == "__main__":
    asyncio.run(get_application_details())
